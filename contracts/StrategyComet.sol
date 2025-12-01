// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IComet {
    function supply(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

/// @title StrategyComet (USDC, supply-only)
/// @notice Shares = 18 decimals. Assets = USDC (6 decimals).
///         Only the configured Vault can deposit/withdraw. No leverage, no borrows.
contract StrategyComet is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable USDC;          // 6 decimals
    IComet public immutable COMET;
    address public immutable VAULT;

    error NotVault();
    modifier onlyVault() {
        if (msg.sender != VAULT) revert NotVault();
        _;
    }

    constructor(address usdc, address comet, address vault)
        ERC20("EVO Comet Strategy Shares", "eCOMET-S")
    {
        USDC = IERC20(usdc);
        COMET = IComet(comet);
        VAULT = vault;

        // Pre-approve Comet to pull USDC from this strategy for supply ops (if needed).
        USDC.approve(address(COMET), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Total USDC managed by this strategy inside Comet.
    function totalAssets() public view returns (uint256) {
        // Comet tracks base asset balances with 6 decimals for USDC markets.
        return COMET.balanceOf(address(this));
    }

    /// @notice Assets per 1e18 shares, returned in USDC's 6-dec units.
    function assetsPerShare() public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 1_000_000; // 1 USDC per share at genesis (in 6-dec units)
        // (totalAssets * 1e18) / totalShares -> result scaled to USDC (6 decimals)
        return (totalAssets() * 1e18) / supply;
    }

    /*//////////////////////////////////////////////////////////////
                        VAULT-ONLY MUTATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit USDC from the Vault and mint shares to `onBehalfOf`.
    /// @param assets USDC amount (6 decimals)
    function deposit(uint256 assets, address onBehalfOf) external nonReentrant onlyVault {
        // Pull USDC from Vault, then supply to Comet
        USDC.safeTransferFrom(msg.sender, address(this), assets);
        // Supply into Comet; Comet will account it under this strategy address
        COMET.supply(address(USDC), assets);

        // Mint shares at current price
        uint256 pps = assetsPerShare(); // 6-dec units per share (scaled)
        // shares = assets * 1e18 / pps
        uint256 shares = (assets * 1e18) / (pps == 0 ? 1_000_000 : pps);
        _mint(onBehalfOf, shares);
    }

    /// @notice Burn `shares` from the Vault and send USDC to `to`.
    /// @param shares Amount of strategy shares to redeem (18 decimals)
    function withdraw(uint256 shares, address to) external nonReentrant onlyVault {
        // Burn shares from the Vault (msg.sender)
        _burn(msg.sender, shares);

        // Compute assets owed with current price
        // assets = shares * pps / 1e18
        uint256 assets = (shares * assetsPerShare()) / 1e18;

        // Withdraw USDC from Comet and send to Vault
        COMET.withdraw(address(USDC), assets);
        USDC.safeTransfer(to, assets);
    }
}
