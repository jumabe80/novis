// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {EUSDv3Premint} from "./token/EUSDv3Premint.sol";

interface IVaultLike {
    function totalBackingUSDC() external view returns (uint256);
}

/// @notice Minimal Aerodrome/Velodrome-style router interface
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

/// @title FortUSDBuyAndBurn
/// @notice Uses excess buffer to buy FortUSD on a DEX (Aerodrome-style router) and burn it.
contract FortUSDBuyAndBurn is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for EUSDv3Premint;

    uint16 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Vault that tracks totalBackingUSDC()
    IVaultLike public immutable vault;
    /// @notice Base USDC
    IERC20 public immutable usdc;
    /// @notice FortUSD token (EUSDv3Premint)
    EUSDv3Premint public immutable fortUSD;
    /// @notice Aerodrome-style router
    IAerodromeRouter public immutable router;

    /// @notice Default single-hop route USDC -> FortUSD
    IAerodromeRouter.Route[] public route;

    /// @notice Buffer threshold (in bps) above which buyAndBurn can be triggered (e.g. 2200 = 22%)
    uint16 public triggerBufferBps;
    /// @notice Max percentage (in bps) of the USDC buffer that can be used per buyAndBurn
    uint16 public maxBuyBufferPctBps;
    /// @notice Cooldown in seconds between buyAndBurn calls
    uint32 public cooldown;
    /// @notice Last timestamp when buyAndBurn was executed
    uint256 public lastBuyAndBurn;

    event BuyAndBurn(
        address indexed caller,
        uint256 usdcIn,
        uint256 fortBurned,
        uint256 backingBps,
        uint256 bufferBps
    );

    constructor(
        address _owner,
        address _vault,
        address _usdc,
        address _fortUSD,
        address _router,
        address _factory,
        bool _stable,
        uint16 _triggerBufferBps,
        uint16 _maxBuyBufferPctBps,
        uint32 _cooldown
    ) Ownable(_owner) {
        require(_owner != address(0), "BB: owner zero");
        require(_vault != address(0), "BB: vault zero");
        require(_usdc != address(0), "BB: usdc zero");
        require(_fortUSD != address(0), "BB: fort zero");
        require(_router != address(0), "BB: router zero");
        require(_factory != address(0), "BB: factory zero");

        vault = IVaultLike(_vault);
        usdc = IERC20(_usdc);
        fortUSD = EUSDv3Premint(_fortUSD);
        router = IAerodromeRouter(_router);

        triggerBufferBps = _triggerBufferBps;
        maxBuyBufferPctBps = _maxBuyBufferPctBps;
        cooldown = _cooldown;

        // Default route: USDC -> FortUSD via given factory + stable flag
        route.push(
            IAerodromeRouter.Route({
                from: _usdc,
                to: _fortUSD,
                stable: _stable,
                factory: _factory
            })
        );
    }

    // ========= View helpers =========

    /// @notice Returns current backing in bps using Vault.totalBackingUSDC and FortUSD.totalSupply
    function backingBps() public view returns (uint256) {
        uint256 backingUSDC = vault.totalBackingUSDC(); // 6 decimals
        uint256 supplyFort = fortUSD.totalSupply();     // 18 decimals

        if (supplyFort == 0) {
            return 0;
        }

        uint256 theoreticalUSDC = supplyFort / 1e12; // normalize 18d -> 6d
        if (theoreticalUSDC == 0) {
            return 0;
        }

        return (backingUSDC * BPS_DENOMINATOR) / theoreticalUSDC;
    }

    /// @notice Returns current buffer (backing - 100%) in bps, floored at 0
    function bufferBps() public view returns (uint256) {
        uint256 backing = backingBps();
        if (backing <= BPS_DENOMINATOR) {
            return 0;
        }
        return backing - BPS_DENOMINATOR;
    }

    /// @notice Returns the USDC buffer (in 6 decimals) and theoretical USDC
    function bufferUSDC() public view returns (uint256 buffer, uint256 theoreticalUSDC) {
        uint256 backingUSDC = vault.totalBackingUSDC();
        uint256 supplyFort = fortUSD.totalSupply();

        theoreticalUSDC = supplyFort / 1e12;
        if (backingUSDC > theoreticalUSDC) {
            buffer = backingUSDC - theoreticalUSDC;
        } else {
            buffer = 0;
        }
    }

    // ========= Owner config =========

    function setTriggerBufferBps(uint16 _triggerBufferBps) external onlyOwner {
        triggerBufferBps = _triggerBufferBps;
    }

    function setMaxBuyBufferPctBps(uint16 _maxBuyBufferPctBps) external onlyOwner {
        require(_maxBuyBufferPctBps <= BPS_DENOMINATOR, "BB: >100%");
        maxBuyBufferPctBps = _maxBuyBufferPctBps;
    }

    function setCooldown(uint32 _cooldown) external onlyOwner {
        cooldown = _cooldown;
    }

    /// @notice Update the default swap route (e.g. if best liquidity moves).
    function setRoute(address _from, address _to, bool _stable, address _factory) external onlyOwner {
        require(_from != address(0) && _to != address(0) && _factory != address(0), "BB: zero addr");

        delete route;
        route.push(
            IAerodromeRouter.Route({
                from: _from,
                to: _to,
                stable: _stable,
                factory: _factory
            })
        );
    }

    // ========= Core action =========

    /// @notice Uses module USDC to buy FortUSD on Aerodrome-style router and burn it.
    /// @param usdcAmount Amount of USDC (6d) to spend from this contract.
    /// @param minFortOut Minimum FortUSD (18d) that must be received, for slippage protection.
    function buyAndBurn(uint256 usdcAmount, uint256 minFortOut) external nonReentrant {
        require(usdcAmount > 0, "BB: amount=0");
        require(minFortOut > 0, "BB: minOut=0");

        uint256 _bufferBps = bufferBps();
        require(_bufferBps >= triggerBufferBps, "BB: buffer too low");

        if (cooldown > 0) {
            require(block.timestamp >= lastBuyAndBurn + cooldown, "BB: cooldown");
        }

        (uint256 bufferUSDCValue, ) = bufferUSDC();
        require(bufferUSDCValue > 0, "BB: no buffer");

        uint256 maxUsdcFromBuffer = (bufferUSDCValue * maxBuyBufferPctBps) / BPS_DENOMINATOR;
        require(usdcAmount <= maxUsdcFromBuffer, "BB: exceeds per-tx buffer");

        uint256 balance = usdc.balanceOf(address(this));
        require(balance >= usdcAmount, "BB: insufficient USDC");

        // Reset allowance then approve exact amount
        usdc.approve(address(router), 0);
        usdc.approve(address(router), usdcAmount);

        IAerodromeRouter.Route[] memory _route = route;

        uint256[] memory amounts = router.swapExactTokensForTokens(
            usdcAmount,
            minFortOut,
            _route,
            address(this),
            block.timestamp + 600
        );

        uint256 fortOut = amounts[amounts.length - 1];
        require(fortOut >= minFortOut, "BB: too little Fort");

        // Burn the received FortUSD (burns from this contract's balance)
        fortUSD.burn(fortOut);

        lastBuyAndBurn = block.timestamp;

        uint256 newBacking = backingBps();
        uint256 newBuffer = bufferBps();

        emit BuyAndBurn(msg.sender, usdcAmount, fortOut, newBacking, newBuffer);
    }
}
