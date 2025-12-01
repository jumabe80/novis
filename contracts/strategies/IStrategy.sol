// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    /// @notice underlying asset (USDC)
    function asset() external view returns (address);

    /// @notice total value in underlying terms
    function totalAssets() external view returns (uint256);

    /// @notice deposit underlying, receive strategy shares
    function deposit(uint256 amount, address onBehalfOf) external returns (uint256 shares);

    /// @notice redeem shares, receive underlying
    function withdraw(uint256 shares, address to) external returns (uint256 assetsOut);
}
