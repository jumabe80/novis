// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStrategy} from "./IStrategy.sol";

/**
 * @title MockYieldStrategy
 * @notice Minimal strategy for TESTNET:
 *         - Holds the underlying (USDC) in this contract.
 *         - Mints "shares" to depositor based on totalAssets/totalShares so
 *           the share price grows when more USDC is donated (simulated yield).
 *         - Anyone can "donate" USDC to simulate external yield.
 *
 *         This is NOT production code — it’s a simple, transparent toy to prove
 *         the yield-bearing mechanics end-to-end.
 */
contract MockYieldStrategy is IStrategy {
    using SafeERC20 for IERC20;

    // ---------- Immutable config ----------
    IERC20 public immutable ASSET; // e.g. USDC
    uint8 public immutable ASSET_DECIMALS; // e.g. 6
    uint256 public immutable SCALE; // 10^(18 - assetDecimals), maps assets -> 18d shares at init

    // ---------- Share accounting ----------
    uint256 public totalShares; // 18 decimals
    mapping(address => uint256) public balanceOf; // shares per owner (18 decimals)

    // ---------- Events ----------
    event Deposit(address indexed caller, address indexed onBehalfOf, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed to, uint256 assets, uint256 shares);
    event Donate(address indexed from, uint256 assets);

    constructor(address asset_) {
        ASSET = IERC20(asset_);
        ASSET_DECIMALS = IERC20Metadata(asset_).decimals();
        require(ASSET_DECIMALS <= 18, "decimals>18");

        // Example for USDC(6): SCALE = 1e12; first deposit: shares = assets * 1e12 (18d)
        SCALE = 10 ** uint256(18 - ASSET_DECIMALS);
    }

    // ===== IStrategy =====

    function asset() external view override returns (address) {
        return address(ASSET);
    }

    /// @notice total value of assets held by the strategy
    function totalAssets() public view override returns (uint256) {
        return ASSET.balanceOf(address(this));
    }

    /// @notice deposit `amount` assets, mint shares to `onBehalfOf`
    function deposit(uint256 amount, address onBehalfOf) external override returns (uint256 shares) {
        require(amount > 0, "amount=0");

        uint256 _totalShares = totalShares;
        uint256 _totalAssets = totalAssets();

        if (_totalShares == 0 || _totalAssets == 0) {
            // First LP sets the initial exchange rate 1:1 (assets * SCALE -> 18d shares)
            shares = amount * SCALE;
        } else {
            // Standard pro-rata mint: shares = amount * totalShares / totalAssets
            shares = amount * _totalShares / _totalAssets;
        }

        totalShares = _totalShares + shares;
        balanceOf[onBehalfOf] += shares;

        ASSET.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, onBehalfOf, amount, shares);
    }

    /// @notice burn `shares` from msg.sender, send assets to `to`
    function withdraw(uint256 shares, address to) external override returns (uint256 assetsOut) {
        require(shares > 0, "shares=0");
        uint256 bal = balanceOf[msg.sender];
        require(bal >= shares, "insufficient shares");

        uint256 _totalShares = totalShares;
        uint256 _totalAssets = totalAssets();

        // assetsOut = shares * totalAssets / totalShares
        assetsOut = shares * _totalAssets / _totalShares;

        // Burn shares
        balanceOf[msg.sender] = bal - shares;
        totalShares = _totalShares - shares;

        ASSET.safeTransfer(to, assetsOut);

        emit Withdraw(msg.sender, to, assetsOut, shares);
    }

    // ===== Helpers for demo/yield sim =====

    /// @notice simulate external yield by donating more ASSET into the strategy.
    ///         Caller must approve this contract first.
    function donate(uint256 amount) external {
        require(amount > 0, "amount=0");
        ASSET.safeTransferFrom(msg.sender, address(this), amount);
        emit Donate(msg.sender, amount);
        // NOTE: No shares are minted => exchange rate goes up for existing LPs.
    }

    /// @notice view helper: current exchange rate (assets per 1e18 shares), 18 decimals
    function assetsPerShare() external view returns (uint256) {
        uint256 _totalShares = totalShares;
        if (_totalShares == 0) return SCALE; // initial 1:1 (e.g. 1e12 assets per 1e18 shares for USDC)
        return totalAssets() * 1e18 / _totalShares;
    }
}
