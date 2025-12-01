// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal interface for Vault
interface IVaultV2 {
    function totalBackingUSDC() external view returns (uint256);
    function deallocate(uint256 shares) external;
    function allocate(uint256 amount) external;
    function strategyShares() external view returns (uint256);
}

/// @notice Minimal interface for NOVIS token (burnable)
interface INOVIS is IERC20 {
    function burn(uint256 amount) external;
    function totalSupply() external view returns (uint256);
}

/// @notice Minimal Aerodrome router interface
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

/// @title ReservePolicyV4
/// @notice Policy contract with integrated Buy & Burn - fully automated yield burning
/// @dev Anyone can trigger buyAndBurn() when conditions are met (permissionless)
contract ReservePolicyV4 {
    using SafeERC20 for IERC20;
    using SafeERC20 for INOVIS;

    // ============ Constants ============
    uint16 public constant BPS_DENOMINATOR = 10_000;

    // ============ Immutables ============
    IVaultV2 public immutable vault;
    INOVIS public immutable novis;
    IERC20 public immutable usdc;
    IAerodromeRouter public immutable router;
    address public immutable factory;

    // ============ State ============
    address public owner;
    address public guardian;
    
    // Buy & Burn parameters
    uint16 public triggerBufferBps;      // Min buffer to trigger (e.g., 1000 = 10%)
    uint16 public maxBuyBps;             // Max % of buffer per burn (e.g., 5000 = 50%)
    uint32 public cooldown;              // Seconds between burns
    uint256 public lastBuyAndBurn;       // Last execution timestamp
    bool public buyAndBurnEnabled;       // Kill switch
    bool public stable;                  // Pool type (stable or volatile)
    
    // Treasury
    address public treasury;
    uint16 public treasuryFeeBps;        // % of yield to treasury (e.g., 1000 = 10%)

    // ============ Events ============
    event BuyAndBurn(
        address indexed caller,
        uint256 usdcSpent,
        uint256 novisBurned,
        uint256 treasuryFee,
        uint256 newBackingBps
    );
    event OwnerSet(address indexed newOwner);
    event GuardianSet(address indexed newGuardian);
    event TreasurySet(address indexed newTreasury);
    event BuyAndBurnParamsSet(uint16 triggerBps, uint16 maxBuyBps, uint32 cooldown, uint16 treasuryFeeBps);
    event BuyAndBurnToggled(bool enabled);

    // ============ Modifiers ============
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }
    
    modifier onlyGuardianOrOwner() {
        require(msg.sender == owner || msg.sender == guardian, "only guardian/owner");
        _;
    }

    // ============ Constructor ============
    constructor(
        address _owner,
        address _vault,
        address _novis,
        address _usdc,
        address _router,
        address _factory,
        address _treasury
    ) {
        require(_owner != address(0), "owner zero");
        require(_vault != address(0), "vault zero");
        require(_novis != address(0), "novis zero");
        require(_usdc != address(0), "usdc zero");
        require(_router != address(0), "router zero");
        require(_factory != address(0), "factory zero");
        
        owner = _owner;
        vault = IVaultV2(_vault);
        novis = INOVIS(_novis);
        usdc = IERC20(_usdc);
        router = IAerodromeRouter(_router);
        factory = _factory;
        treasury = _treasury;
        
        // Default parameters
        triggerBufferBps = 1000;     // 10% buffer required
        maxBuyBps = 5000;            // Max 50% of buffer per tx
        cooldown = 1 days;           // 1 day between burns
        treasuryFeeBps = 1000;       // 10% to treasury
        buyAndBurnEnabled = true;
        stable = false;              // Volatile pool
    }

    // ============ View Functions ============
    
    /// @notice Current backing in basis points (10000 = 100%)
    function backingBps() public view returns (uint256) {
        uint256 backing = vault.totalBackingUSDC(); // 6 decimals
        uint256 supply = novis.totalSupply();       // 18 decimals
        
        if (supply == 0) return 0;
        
        uint256 theoreticalUSDC = supply / 1e12;    // Convert 18d → 6d
        if (theoreticalUSDC == 0) return 0;
        
        return (backing * BPS_DENOMINATOR) / theoreticalUSDC;
    }
    
    /// @notice Current buffer in basis points (above 100%)
    function bufferBps() public view returns (uint256) {
        uint256 backing = backingBps();
        if (backing <= BPS_DENOMINATOR) return 0;
        return backing - BPS_DENOMINATOR;
    }
    
    /// @notice Buffer in USDC (6 decimals)
    function bufferUSDC() public view returns (uint256 buffer, uint256 theoreticalUSDC) {
        uint256 backing = vault.totalBackingUSDC();
        uint256 supply = novis.totalSupply();
        
        theoreticalUSDC = supply / 1e12;
        buffer = backing > theoreticalUSDC ? backing - theoreticalUSDC : 0;
    }
    
    /// @notice Check if buyAndBurn can be called
    function canBuyAndBurn() public view returns (bool) {
        if (!buyAndBurnEnabled) return false;
        if (bufferBps() < triggerBufferBps) return false;
        if (block.timestamp < lastBuyAndBurn + cooldown) return false;
        return true;
    }
    
    /// @notice Calculate max USDC that can be used for buyAndBurn
    function maxBuyAndBurnUSDC() public view returns (uint256) {
        (uint256 buffer, ) = bufferUSDC();
        return (buffer * maxBuyBps) / BPS_DENOMINATOR;
    }

    // ============ Core: Buy & Burn ============
    
    /// @notice Execute buy and burn - PERMISSIONLESS, anyone can call
    /// @param usdcAmount Amount of USDC to use (must be ≤ maxBuyAndBurnUSDC)
    /// @param minNovisOut Minimum NOVIS to receive (slippage protection)
    function buyAndBurn(uint256 usdcAmount, uint256 minNovisOut) external {
        require(buyAndBurnEnabled, "disabled");
        require(bufferBps() >= triggerBufferBps, "buffer too low");
        require(block.timestamp >= lastBuyAndBurn + cooldown, "cooldown");
        require(usdcAmount > 0, "amount zero");
        require(minNovisOut > 0, "minOut zero");
        
        uint256 maxAmount = maxBuyAndBurnUSDC();
        require(usdcAmount <= maxAmount, "exceeds max");
        
        // Calculate treasury fee
        uint256 treasuryFee = (usdcAmount * treasuryFeeBps) / BPS_DENOMINATOR;
        uint256 burnAmount = usdcAmount - treasuryFee;
        
        // 1. Deallocate from strategy to get USDC in vault
        //    (Vault will pull from strategy if needed)
        uint256 vaultUSDCBefore = usdc.balanceOf(address(vault));
        if (vaultUSDCBefore < usdcAmount) {
            // Need to deallocate from strategy
            uint256 needed = usdcAmount - vaultUSDCBefore;
            vault.deallocate(needed); // This moves USDC from strategy to vault
        }
        
        // 2. Transfer USDC from vault to this contract
        //    We use exec pattern - vault owner is this policy
        usdc.safeTransferFrom(address(vault), address(this), usdcAmount);
        
        // 3. Send treasury fee
        if (treasuryFee > 0 && treasury != address(0)) {
            usdc.safeTransfer(treasury, treasuryFee);
        }
        
        // 4. Swap USDC → NOVIS on Aerodrome
        usdc.approve(address(router), burnAmount);
        
        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({
            from: address(usdc),
            to: address(novis),
            stable: stable,
            factory: factory
        });
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            burnAmount,
            minNovisOut,
            routes,
            address(this),
            block.timestamp + 600
        );
        
        uint256 novisReceived = amounts[amounts.length - 1];
        require(novisReceived >= minNovisOut, "slippage");
        
        // 5. Burn the NOVIS
        novis.burn(novisReceived);
        
        // 6. Update state
        lastBuyAndBurn = block.timestamp;
        
        emit BuyAndBurn(msg.sender, usdcAmount, novisReceived, treasuryFee, backingBps());
    }

    // ============ Owner Functions ============
    
    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "zero");
        owner = _owner;
        emit OwnerSet(_owner);
    }
    
    function setGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
        emit GuardianSet(_guardian);
    }
    
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }
    
    function setBuyAndBurnParams(
        uint16 _triggerBufferBps,
        uint16 _maxBuyBps,
        uint32 _cooldown,
        uint16 _treasuryFeeBps
    ) external onlyOwner {
        require(_maxBuyBps <= BPS_DENOMINATOR, "maxBuy > 100%");
        require(_treasuryFeeBps <= BPS_DENOMINATOR, "fee > 100%");
        
        triggerBufferBps = _triggerBufferBps;
        maxBuyBps = _maxBuyBps;
        cooldown = _cooldown;
        treasuryFeeBps = _treasuryFeeBps;
        
        emit BuyAndBurnParamsSet(_triggerBufferBps, _maxBuyBps, _cooldown, _treasuryFeeBps);
    }
    
    function setPoolType(bool _stable) external onlyOwner {
        stable = _stable;
    }
    
    function toggleBuyAndBurn(bool _enabled) external onlyGuardianOrOwner {
        buyAndBurnEnabled = _enabled;
        emit BuyAndBurnToggled(_enabled);
    }

    // ============ Vault Management ============
    
    /// @notice Allocate USDC from vault to strategy
    function allocate(uint256 amount) external onlyOwner {
        vault.allocate(amount);
    }
    
    /// @notice Deallocate from strategy to vault
    function deallocate(uint256 shares) external onlyOwner {
        vault.deallocate(shares);
    }
    
    /// @notice Generic exec for vault management
    function exec(address target, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory) {
        (bool ok, bytes memory ret) = target.call{value: value}(data);
        require(ok, "exec failed");
        return ret;
    }
    
    // ============ Emergency ============
    
    /// @notice Rescue stuck tokens (not USDC or NOVIS)
    function rescueToken(address token, uint256 amount) external onlyOwner {
        require(token != address(usdc) && token != address(novis), "protected");
        IERC20(token).safeTransfer(owner, amount);
    }
}
