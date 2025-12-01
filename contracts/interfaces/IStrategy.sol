// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Minimal interface your VaultV2 needs.
/// (Matches the functions your MockStrategy exposes.)
interface IStrategy {
    /// Underlying asset (USDC)
    function asset() external view returns (address);

    /// Total USDC-equivalent assets the strategy currently holds (6 decimals)
    function totalAssets() external view returns (uint256);

    /// Deposit `amount` USDC, mint shares to `onBehalfOf`
    /// Returns shares minted (18 decimals)
    function deposit(uint256 amount, address onBehalfOf) external returns (uint256 shares);

    /// Burn `shares` and return underlying USDC to `to`
    /// Returns assets sent out (USDC, 6 decimals)
    function withdraw(uint256 shares, address to) external returns (uint256 assetsOut);
}
