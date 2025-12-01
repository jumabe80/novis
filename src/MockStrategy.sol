// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal yield strategy for USDC (6 decimals) that mints 18-decimal "shares".
/// - deposit(assets, onBehalfOf): pulls USDC and mints shares
/// - withdraw(shares, to): burns shares and sends USDC
/// - donate(amount): pull USDC into the strategy to simulate yield
/// - totalAssets(): USDC balance held by this strategy
/// - assetsPerShare(): (totalAssets * 1e18) / totalShares
contract MockStrategy is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc; // underlying asset (6d)

    constructor(address _usdc) ERC20("Mock Strategy Share", "mSTRAT") {
        require(_usdc != address(0), "usdc=0");
        usdc = IERC20(_usdc);
    }

    /// @notice Return underlying asset (for interface compatibility).
    function asset() external view returns (address) {
        return address(usdc);
    }

    function totalAssets() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    /// @notice WAD-scaled assets per 1e18 shares.
    function assetsPerShare() public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;
        return (totalAssets() * 1e18) / supply;
    }

    /// @notice Deposit `assets` USDC and mint shares to `onBehalfOf`.
    /// Bootstrap: 1 USDC (1e6) -> 1e18 shares (multiplier 1e12)
    function deposit(uint256 assets, address onBehalfOf) external returns (uint256 shares) {
        require(assets > 0, "amount=0");

        uint256 supply = totalSupply();
        uint256 assetsBefore = totalAssets();

        if (supply == 0 || assetsBefore == 0) {
            shares = assets * 1e12;
        } else {
            shares = (assets * supply) / assetsBefore;
        }

        usdc.safeTransferFrom(msg.sender, address(this), assets);
        _mint(onBehalfOf, shares);
    }

    /// @notice Burn `shares` and send proportional USDC to `to`.
    function withdraw(uint256 shares, address to) external returns (uint256 assetsOut) {
        require(shares > 0, "shares=0");
        uint256 supply = totalSupply();
        require(supply > 0, "no-supply");

        assetsOut = (shares * totalAssets()) / supply;

        _burn(msg.sender, shares);
        usdc.safeTransfer(to, assetsOut);
    }

    /// @notice Pull USDC into this contract to simulate yield.
    function donate(uint256 amount) external {
        require(amount > 0, "amount=0");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
    }
}
