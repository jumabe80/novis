// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title VaultV3 (Auto-Burn Edition)
 * @notice All-in-one vault with AUTO-TRIGGERED Buy & Burn
 */

interface INOVISv2 is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}

interface IStrategy {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function deposit(uint256 amount, address onBehalfOf) external returns (uint256 shares);
    function withdraw(uint256 shares, address to) external returns (uint256 assets);
}

interface IAerodromeRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }
    
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract VaultV3 is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for INOVISv2;

    uint256 private constant SCALE = 1e12;
    uint16 public constant BPS_DENOMINATOR = 10_000;

    IERC20 public immutable usdc;
    INOVISv2 public immutable novis;
    IAerodromeRouter public immutable router;
    address public immutable factory;

    IStrategy public strategy;
    address public treasury;
    
    uint16 public triggerBufferBps;
    uint16 public maxBuyBps;
    uint16 public treasuryFeeBps;
    uint16 public autoSlippageBps;
    uint32 public cooldown;
    uint256 public lastBuyAndBurn;
    bool public buyAndBurnEnabled;
    bool public autoBurnEnabled;
    bool public poolStable;

    event Deposit(address indexed user, uint256 usdcAmount, uint256 novisMinted);
    event Redeem(address indexed user, uint256 novisBurned, uint256 usdcReturned);
    event StrategySet(address indexed strategy);
    event TreasurySet(address indexed treasury);
    event Allocated(uint256 usdcAmount, uint256 sharesReceived);
    event Deallocated(uint256 sharesBurned, uint256 usdcReceived);
    event BuyAndBurn(address indexed caller, uint256 usdcSpent, uint256 novisBurned, uint256 treasuryFee, uint256 newBackingBps);
    event AutoBuyAndBurnFailed(string reason);
    event BuyAndBurnParamsSet(uint16 triggerBps, uint16 maxBuyBps, uint16 treasuryFeeBps, uint32 cooldown);
    event BuyAndBurnToggled(bool enabled);
    event AutoBurnToggled(bool enabled);
    event TokenOwnershipTransferred(address indexed newOwner);
    event TokensRescued(address indexed token, uint256 amount);
    event ETHRescued(uint256 amount);

    constructor(
        address _owner,
        address _usdc,
        address _novis,
        address _router,
        address _factory,
        address _treasury
    ) Ownable(_owner) {
        require(_usdc != address(0), "usdc zero");
        require(_novis != address(0), "novis zero");
        require(_router != address(0), "router zero");
        require(_factory != address(0), "factory zero");
        
        usdc = IERC20(_usdc);
        novis = INOVISv2(_novis);
        router = IAerodromeRouter(_router);
        factory = _factory;
        treasury = _treasury;
        
        triggerBufferBps = 1000;
        maxBuyBps = 5000;
        treasuryFeeBps = 1000;
        autoSlippageBps = 500;
        cooldown = 1 days;
        buyAndBurnEnabled = true;
        autoBurnEnabled = true;
        poolStable = false;
    }

    function deposit(uint256 usdcAmount) external whenNotPaused nonReentrant {
        require(usdcAmount > 0, "amount zero");
        
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        
        uint256 novisAmount = usdcAmount * SCALE;
        novis.mint(msg.sender, novisAmount);
        
        emit Deposit(msg.sender, usdcAmount, novisAmount);
        
        _tryAutoBuyAndBurn();
    }

    function redeem(uint256 novisAmount) external whenNotPaused nonReentrant {
        require(novisAmount > 0, "amount zero");
        
        uint256 usdcAmount = novisAmount / SCALE;
        require(usdcAmount > 0, "amount too small");
        
        uint256 vaultBalance = usdc.balanceOf(address(this));
        if (vaultBalance < usdcAmount) {
            uint256 needed = usdcAmount - vaultBalance;
            _deallocateFromStrategy(needed);
        }
        
        novis.safeTransferFrom(msg.sender, address(this), novisAmount);
        novis.burn(novisAmount);
        
        usdc.safeTransfer(msg.sender, usdcAmount);
        
        emit Redeem(msg.sender, novisAmount, usdcAmount);
        
        _tryAutoBuyAndBurn();
    }

    function vaultUSDC() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function totalBackingUSDC() public view returns (uint256) {
        uint256 inVault = vaultUSDC();
        uint256 inStrategy = address(strategy) != address(0) ? strategy.totalAssets() : 0;
        return inVault + inStrategy;
    }

    function backingBps() public view returns (uint256) {
        uint256 backing = totalBackingUSDC();
        uint256 supply = novis.totalSupply();
        
        if (supply == 0) return BPS_DENOMINATOR;
        
        uint256 theoreticalUSDC = supply / SCALE;
        if (theoreticalUSDC == 0) return BPS_DENOMINATOR;
        
        return (backing * BPS_DENOMINATOR) / theoreticalUSDC;
    }

    function bufferBps() public view returns (uint256) {
        uint256 backing = backingBps();
        if (backing <= BPS_DENOMINATOR) return 0;
        return backing - BPS_DENOMINATOR;
    }

    function bufferUSDC() public view returns (uint256 buffer, uint256 theoreticalUSDC) {
        uint256 backing = totalBackingUSDC();
        uint256 supply = novis.totalSupply();
        
        theoreticalUSDC = supply / SCALE;
        buffer = backing > theoreticalUSDC ? backing - theoreticalUSDC : 0;
    }

    function canBuyAndBurn() public view returns (bool) {
        if (!buyAndBurnEnabled) return false;
        if (bufferBps() < triggerBufferBps) return false;
        if (block.timestamp < lastBuyAndBurn + cooldown) return false;
        return true;
    }

    function maxBuyAndBurnUSDC() public view returns (uint256) {
        (uint256 buffer, ) = bufferUSDC();
        return (buffer * maxBuyBps) / BPS_DENOMINATOR;
    }

    function _tryAutoBuyAndBurn() internal {
        if (!autoBurnEnabled) return;
        if (!buyAndBurnEnabled) return;
        if (bufferBps() < triggerBufferBps) return;
        if (block.timestamp < lastBuyAndBurn + cooldown) return;
        
        uint256 maxAmount = maxBuyAndBurnUSDC();
        if (maxAmount == 0) return;
        
        uint256 burnAmount = maxAmount / 2;
        if (burnAmount < 1e6) return;
        
        uint256 expectedNovis = burnAmount * SCALE;
        uint256 minNovisOut = (expectedNovis * (BPS_DENOMINATOR - autoSlippageBps)) / BPS_DENOMINATOR;
        
        try this.executeBuyAndBurn(burnAmount, minNovisOut) {
        } catch Error(string memory reason) {
            emit AutoBuyAndBurnFailed(reason);
        } catch {
            emit AutoBuyAndBurnFailed("unknown error");
        }
    }

    function executeBuyAndBurn(uint256 usdcAmount, uint256 minNovisOut) external {
        require(msg.sender == address(this), "only self");
        _executeBuyAndBurn(usdcAmount, minNovisOut);
    }

    function _executeBuyAndBurn(uint256 usdcAmount, uint256 minNovisOut) internal {
        uint256 vaultBalance = usdc.balanceOf(address(this));
        if (vaultBalance < usdcAmount) {
            uint256 needed = usdcAmount - vaultBalance;
            _deallocateFromStrategy(needed);
        }
        
        uint256 treasuryFee = (usdcAmount * treasuryFeeBps) / BPS_DENOMINATOR;
        uint256 swapAmount = usdcAmount - treasuryFee;
        
        if (treasuryFee > 0 && treasury != address(0)) {
            usdc.safeTransfer(treasury, treasuryFee);
        }
        
        usdc.approve(address(router), swapAmount);
        
        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({
            from: address(usdc),
            to: address(novis),
            stable: poolStable,
            factory: factory
        });
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            minNovisOut,
            routes,
            address(this),
            block.timestamp + 600
        );
        
        uint256 novisReceived = amounts[amounts.length - 1];
        require(novisReceived >= minNovisOut, "slippage");
        
        novis.burn(novisReceived);
        
        lastBuyAndBurn = block.timestamp;
        
        emit BuyAndBurn(address(this), usdcAmount, novisReceived, treasuryFee, backingBps());
    }

    function buyAndBurn(uint256 usdcAmount, uint256 minNovisOut) external nonReentrant {
        require(buyAndBurnEnabled, "disabled");
        require(bufferBps() >= triggerBufferBps, "buffer too low");
        require(block.timestamp >= lastBuyAndBurn + cooldown, "cooldown");
        require(usdcAmount > 0, "amount zero");
        require(minNovisOut > 0, "minOut zero");
        
        uint256 maxAmount = maxBuyAndBurnUSDC();
        require(usdcAmount <= maxAmount, "exceeds max");
        
        _executeBuyAndBurn(usdcAmount, minNovisOut);
    }

    function setStrategy(address _strategy) external onlyOwner {
        if (_strategy == address(0)) {
            strategy = IStrategy(address(0));
            emit StrategySet(address(0));
            return;
        }
        require(IStrategy(_strategy).asset() == address(usdc), "bad asset");
        strategy = IStrategy(_strategy);
        emit StrategySet(_strategy);
    }

    function allocate(uint256 usdcAmount) external onlyOwner nonReentrant {
        require(address(strategy) != address(0), "no strategy");
        require(usdcAmount > 0, "amount zero");
        
        usdc.approve(address(strategy), usdcAmount);
        uint256 shares = strategy.deposit(usdcAmount, address(this));
        
        emit Allocated(usdcAmount, shares);
    }

    function deallocate(uint256 shares) external onlyOwner nonReentrant {
        require(address(strategy) != address(0), "no strategy");
        require(shares > 0, "shares zero");
        
        uint256 assets = strategy.withdraw(shares, address(this));
        
        emit Deallocated(shares, assets);
    }

    function _deallocateFromStrategy(uint256 needed) internal {
        require(address(strategy) != address(0), "no strategy");
        
        uint256 strategyAssets = strategy.totalAssets();
        require(strategyAssets >= needed, "insufficient strategy balance");
        
        strategy.withdraw(needed, address(this));
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    function setBuyAndBurnParams(
        uint16 _triggerBufferBps,
        uint16 _maxBuyBps,
        uint16 _treasuryFeeBps,
        uint32 _cooldown
    ) external onlyOwner {
        require(_maxBuyBps <= BPS_DENOMINATOR, "maxBuy > 100%");
        require(_treasuryFeeBps <= BPS_DENOMINATOR, "fee > 100%");
        
        triggerBufferBps = _triggerBufferBps;
        maxBuyBps = _maxBuyBps;
        treasuryFeeBps = _treasuryFeeBps;
        cooldown = _cooldown;
        
        emit BuyAndBurnParamsSet(_triggerBufferBps, _maxBuyBps, _treasuryFeeBps, _cooldown);
    }

    function setAutoSlippageBps(uint16 _slippageBps) external onlyOwner {
        require(_slippageBps <= 2000, "slippage > 20%");
        autoSlippageBps = _slippageBps;
    }

    function setPoolStable(bool _stable) external onlyOwner {
        poolStable = _stable;
    }

    function toggleBuyAndBurn(bool _enabled) external onlyOwner {
        buyAndBurnEnabled = _enabled;
        emit BuyAndBurnToggled(_enabled);
    }

    function toggleAutoBurn(bool _enabled) external onlyOwner {
        autoBurnEnabled = _enabled;
        emit AutoBurnToggled(_enabled);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rescueToken(address token, uint256 amount) external onlyOwner {
        if (token == address(usdc)) {
            uint256 supply = novis.totalSupply();
            uint256 requiredBacking = supply / SCALE;
            uint256 currentBacking = totalBackingUSDC();
            require(currentBacking > requiredBacking, "no excess");
            uint256 excess = currentBacking - requiredBacking;
            require(amount <= excess, "exceeds excess");
        }
        
        IERC20(token).safeTransfer(owner(), amount);
        emit TokensRescued(token, amount);
    }

    function rescueETH(uint256 amount) external onlyOwner {
        (bool success, ) = owner().call{value: amount}("");
        require(success, "ETH transfer failed");
        emit ETHRescued(amount);
    }

    function transferTokenOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "new owner zero");
        novis.transferOwnership(newOwner);
        emit TokenOwnershipTransferred(newOwner);
    }

    receive() external payable {}
}
