// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

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
    struct Route { address from; address to; bool stable; address factory; }
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, Route[] calldata routes, address to, uint256 deadline) external returns (uint256[] memory amounts);
}

contract VaultV3UpgradeableV3 is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuard, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for INOVISv2;

    uint256 private constant SCALE = 1e12;
    uint16 public constant BPS_DENOMINATOR = 10_000;

    IERC20 public usdc;
    INOVISv2 public novis;
    IAerodromeRouter public router;
    address public factory;
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

    // NEW: Fee system
    uint256 public feeThreshold;      // Below this = no fee (default 10 USDC = 10e6)
    uint16 public depositFeeBps;       // Fee for deposits >= threshold (default 50 = 0.5%)
    bool public feesEnabled;           // Kill switch for fees

    uint256[47] private __gap;  // Reduced gap for new variables

    event Deposit(address indexed user, uint256 usdcAmount, uint256 novisMinted, uint256 fee);
    event Redeem(address indexed user, uint256 novisBurned, uint256 usdcReturned);
    event StrategySet(address indexed strategy);
    event TreasurySet(address indexed treasury);
    event RouterSet(address indexed router);
    event Allocated(uint256 usdcAmount, uint256 sharesReceived);
    event Deallocated(uint256 sharesBurned, uint256 usdcReceived);
    event BuyAndBurn(address indexed caller, uint256 usdcSpent, uint256 novisBurned, uint256 treasuryFee, uint256 newBackingBps);
    event AutoBuyAndBurnFailed(string reason);
    event BuyAndBurnParamsSet(uint16 triggerBps, uint16 maxBuyBps, uint16 treasuryFeeBps, uint32 cooldown);
    event BuyAndBurnToggled(bool enabled);
    event AutoBurnToggled(bool enabled);
    event FeeParamsSet(uint256 threshold, uint16 feeBps, bool enabled);
    event TokenOwnershipTransferred(address indexed newOwner);
    event TokensRescued(address indexed token, uint256 amount);
    event ETHRescued(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address _owner, address _usdc, address _novis, address _router, address _factory, address _treasury) public initializer {
        __Ownable_init(_owner);
        __Pausable_init();
        require(_usdc != address(0) && _novis != address(0) && _router != address(0) && _factory != address(0), "zero addr");
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
        // Fee defaults
        feeThreshold = 10e6;  // 10 USDC
        depositFeeBps = 50;    // 0.5%
        feesEnabled = true;
    }

    // Called after upgrade to initialize new variables
    function initializeV3() external onlyOwner {
        if (feeThreshold == 0) {
            feeThreshold = 10e6;  // 10 USDC
            depositFeeBps = 50;    // 0.5%
            feesEnabled = true;
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function deposit(uint256 usdcAmount) external whenNotPaused nonReentrant {
        require(usdcAmount > 0, "amount zero");
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        
        // Calculate fee
        uint256 fee = 0;
        uint256 netAmount = usdcAmount;
        if (feesEnabled && usdcAmount >= feeThreshold) {
            fee = (usdcAmount * depositFeeBps) / BPS_DENOMINATOR;
            netAmount = usdcAmount - fee;
            if (fee > 0 && treasury != address(0)) {
                usdc.safeTransfer(treasury, fee);
            }
        }
        
        uint256 novisAmount = netAmount * SCALE;
        novis.mint(msg.sender, novisAmount);
        
        emit Deposit(msg.sender, usdcAmount, novisAmount, fee);
        _tryAutoBuyAndBurn();
    }

    function redeem(uint256 novisAmount) external whenNotPaused nonReentrant {
        require(novisAmount > 0, "amount zero");
        uint256 usdcAmount = novisAmount / SCALE;
        require(usdcAmount > 0, "amount too small");
        uint256 vaultBalance = usdc.balanceOf(address(this));
        if (vaultBalance < usdcAmount) { _deallocateFromStrategy(usdcAmount - vaultBalance); }
        novis.safeTransferFrom(msg.sender, address(this), novisAmount);
        novis.burn(novisAmount);
        usdc.safeTransfer(msg.sender, usdcAmount);
        emit Redeem(msg.sender, novisAmount, usdcAmount);
        _tryAutoBuyAndBurn();
    }

    function vaultUSDC() public view returns (uint256) { return usdc.balanceOf(address(this)); }
    function totalBackingUSDC() public view returns (uint256) { return vaultUSDC() + (address(strategy) != address(0) ? strategy.totalAssets() : 0); }
    function backingBps() public view returns (uint256) {
        uint256 backing = totalBackingUSDC();
        uint256 supply = novis.totalSupply();
        if (supply == 0) return BPS_DENOMINATOR;
        uint256 theoreticalUSDC = supply / SCALE;
        if (theoreticalUSDC == 0) return BPS_DENOMINATOR;
        return (backing * BPS_DENOMINATOR) / theoreticalUSDC;
    }
    function bufferBps() public view returns (uint256) { uint256 b = backingBps(); return b <= BPS_DENOMINATOR ? 0 : b - BPS_DENOMINATOR; }
    function bufferUSDC() public view returns (uint256 buffer, uint256 theoreticalUSDC) {
        uint256 backing = totalBackingUSDC();
        uint256 supply = novis.totalSupply();
        theoreticalUSDC = supply / SCALE;
        buffer = backing > theoreticalUSDC ? backing - theoreticalUSDC : 0;
    }
    function canBuyAndBurn() public view returns (bool) { return buyAndBurnEnabled && bufferBps() >= triggerBufferBps && block.timestamp >= lastBuyAndBurn + cooldown; }
    function maxBuyAndBurnUSDC() public view returns (uint256) { (uint256 buffer, ) = bufferUSDC(); return (buffer * maxBuyBps) / BPS_DENOMINATOR; }

    // Calculate deposit fee for UI
    function calculateDepositFee(uint256 usdcAmount) external view returns (uint256 fee, uint256 netAmount) {
        if (!feesEnabled || usdcAmount < feeThreshold) {
            return (0, usdcAmount);
        }
        fee = (usdcAmount * depositFeeBps) / BPS_DENOMINATOR;
        netAmount = usdcAmount - fee;
    }

    function _tryAutoBuyAndBurn() internal {
        if (!autoBurnEnabled || !buyAndBurnEnabled) return;
        if (bufferBps() < triggerBufferBps || block.timestamp < lastBuyAndBurn + cooldown) return;
        uint256 maxAmount = maxBuyAndBurnUSDC();
        if (maxAmount == 0) return;
        uint256 burnAmount = maxAmount / 2;
        if (burnAmount < 1e6) return;
        uint256 treasuryFee = (burnAmount * treasuryFeeBps) / BPS_DENOMINATOR;
        uint256 swapAmount = burnAmount - treasuryFee;
        uint256 minNovisOut = (swapAmount * SCALE * (BPS_DENOMINATOR - autoSlippageBps)) / BPS_DENOMINATOR;
        try this.executeBuyAndBurn(burnAmount, minNovisOut) {} catch Error(string memory reason) { emit AutoBuyAndBurnFailed(reason); } catch { emit AutoBuyAndBurnFailed("unknown"); }
    }

    function executeBuyAndBurn(uint256 usdcAmount, uint256 minNovisOut) external {
        require(msg.sender == address(this), "only self");
        _executeBuyAndBurn(usdcAmount, minNovisOut);
    }

    function _executeBuyAndBurn(uint256 usdcAmount, uint256 minNovisOut) internal {
        uint256 vaultBalance = usdc.balanceOf(address(this));
        if (vaultBalance < usdcAmount) { _deallocateFromStrategy(usdcAmount - vaultBalance); }
        uint256 tFee = (usdcAmount * treasuryFeeBps) / BPS_DENOMINATOR;
        uint256 swapAmount = usdcAmount - tFee;
        if (tFee > 0 && treasury != address(0)) { usdc.safeTransfer(treasury, tFee); }
        usdc.approve(address(router), swapAmount);
        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({ from: address(usdc), to: address(novis), stable: poolStable, factory: factory });
        uint256[] memory amounts = router.swapExactTokensForTokens(swapAmount, minNovisOut, routes, address(this), block.timestamp + 600);
        uint256 novisReceived = amounts[amounts.length - 1];
        require(novisReceived >= minNovisOut, "slippage");
        novis.burn(novisReceived);
        lastBuyAndBurn = block.timestamp;
        emit BuyAndBurn(address(this), usdcAmount, novisReceived, tFee, backingBps());
    }

    function buyAndBurn(uint256 usdcAmount, uint256 minNovisOut) external nonReentrant {
        require(buyAndBurnEnabled, "disabled");
        require(bufferBps() >= triggerBufferBps, "buffer too low");
        require(block.timestamp >= lastBuyAndBurn + cooldown, "cooldown");
        require(usdcAmount > 0 && minNovisOut > 0, "zero");
        require(usdcAmount <= maxBuyAndBurnUSDC(), "exceeds max");
        _executeBuyAndBurn(usdcAmount, minNovisOut);
    }

    function setStrategy(address _strategy) external onlyOwner {
        if (_strategy == address(0)) { strategy = IStrategy(address(0)); emit StrategySet(address(0)); return; }
        require(IStrategy(_strategy).asset() == address(usdc), "bad asset");
        strategy = IStrategy(_strategy);
        emit StrategySet(_strategy);
    }
    function allocate(uint256 usdcAmount) external onlyOwner nonReentrant {
        require(address(strategy) != address(0) && usdcAmount > 0, "invalid");
        usdc.approve(address(strategy), usdcAmount);
        uint256 shares = strategy.deposit(usdcAmount, address(this));
        emit Allocated(usdcAmount, shares);
    }
    function deallocate(uint256 shares) external onlyOwner nonReentrant {
        require(address(strategy) != address(0) && shares > 0, "invalid");
        uint256 assets = strategy.withdraw(shares, address(this));
        emit Deallocated(shares, assets);
    }
    function _deallocateFromStrategy(uint256 needed) internal {
        require(address(strategy) != address(0), "no strategy");
        require(strategy.totalAssets() >= needed, "insufficient");
        strategy.withdraw(needed, address(this));
    }

    function setTreasury(address _treasury) external onlyOwner { treasury = _treasury; emit TreasurySet(_treasury); }
    function setRouter(address _router) external onlyOwner { require(_router != address(0), "zero"); router = IAerodromeRouter(_router); emit RouterSet(_router); }
    function setFactory(address _factory) external onlyOwner { require(_factory != address(0), "zero"); factory = _factory; }
    function setBuyAndBurnParams(uint16 _triggerBufferBps, uint16 _maxBuyBps, uint16 _treasuryFeeBps, uint32 _cooldown) external onlyOwner {
        require(_maxBuyBps <= BPS_DENOMINATOR && _treasuryFeeBps <= BPS_DENOMINATOR, "invalid");
        triggerBufferBps = _triggerBufferBps; maxBuyBps = _maxBuyBps; treasuryFeeBps = _treasuryFeeBps; cooldown = _cooldown;
        emit BuyAndBurnParamsSet(_triggerBufferBps, _maxBuyBps, _treasuryFeeBps, _cooldown);
    }
    function setAutoSlippageBps(uint16 _slippageBps) external onlyOwner { require(_slippageBps <= 2000, ">20%"); autoSlippageBps = _slippageBps; }
    function setPoolStable(bool _stable) external onlyOwner { poolStable = _stable; }
    function toggleBuyAndBurn(bool _enabled) external onlyOwner { buyAndBurnEnabled = _enabled; emit BuyAndBurnToggled(_enabled); }
    function toggleAutoBurn(bool _enabled) external onlyOwner { autoBurnEnabled = _enabled; emit AutoBurnToggled(_enabled); }
    
    // NEW: Fee configuration
    function setFeeParams(uint256 _threshold, uint16 _feeBps, bool _enabled) external onlyOwner {
        require(_feeBps <= 1000, "fee > 10%");  // Max 10% fee
        feeThreshold = _threshold;
        depositFeeBps = _feeBps;
        feesEnabled = _enabled;
        emit FeeParamsSet(_threshold, _feeBps, _enabled);
    }
    
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function rescueToken(address token, uint256 amount) external onlyOwner {
        if (token == address(usdc)) {
            uint256 required = novis.totalSupply() / SCALE;
            uint256 current = totalBackingUSDC();
            require(current > required && amount <= current - required, "exceeds excess");
        }
        IERC20(token).safeTransfer(owner(), amount);
        emit TokensRescued(token, amount);
    }
    function rescueETH(uint256 amount) external onlyOwner { (bool s, ) = owner().call{value: amount}(""); require(s, "failed"); emit ETHRescued(amount); }
    function transferTokenOwnership(address newOwner) external onlyOwner { require(newOwner != address(0), "zero"); novis.transferOwnership(newOwner); emit TokenOwnershipTransferred(newOwner); }
    function version() external pure returns (string memory) { return "1.2.0"; }
    receive() external payable {}
}
