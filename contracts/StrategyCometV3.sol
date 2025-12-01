// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal interface for Comet / MockComet we care about.
interface ICometLike {
    function supply(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Strategy that takes USDC from the Vault and supplies into a Comet-like market.
/// Shares represent a claim on the underlying assets held in Comet.
contract StrategyCometV3 is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    ICometLike public immutable comet;
    address public immutable vault;

    modifier onlyVault() {
        require(msg.sender == vault, "StrategyCometV3: only vault");
        _;
    }

    constructor(address _usdc, address _comet, address _vault)
        ERC20("EUSD Comet Strategy Share", "eusdCOMETv3")
    {
        require(_usdc != address(0), "StrategyCometV3: usdc=0");
        require(_comet != address(0), "StrategyCometV3: comet=0");
        require(_vault != address(0), "StrategyCometV3: vault=0");

        usdc = IERC20(_usdc);
        comet = ICometLike(_comet);
        vault = _vault;
    }

    /// @notice Underlying asset (USDC).
    function asset() external view returns (address) {
        return address(usdc);
    }

    /// @notice Total USDC-equivalent held in Comet for this strategy.
    function totalAssets() public view returns (uint256) {
        return comet.balanceOf(address(this));
    }

    /// @notice Deposit USDC from the Vault into Comet and mint strategy shares to `onBehalfOf`.
    /// @dev Only the Vault may call this.
    function deposit(uint256 assets, address onBehalfOf) external onlyVault returns (uint256 shares) {
        require(assets > 0, "StrategyCometV3: assets=0");
        require(onBehalfOf != address(0), "StrategyCometV3: onBehalfOf=0");

        // Snapshot total assets *before* supplying.
        uint256 prevAssets = totalAssets();
        uint256 supplyShares = totalSupply();

        // Pull USDC from the Vault into this strategy.
        usdc.safeTransferFrom(msg.sender, address(this), assets);

        // Approve Comet to pull USDC from this strategy.
        usdc.approve(address(comet), 0);
        usdc.approve(address(comet), assets);

        // Supply into Comet.
        comet.supply(address(usdc), assets);

        // Mint shares pro-rata versus previous TVL.
        if (supplyShares == 0 || prevAssets == 0) {
            // First depositor: 1:1 mapping between assets and shares.
            shares = assets;
        } else {
            shares = (assets * supplyShares) / prevAssets;
        }

        require(shares > 0, "StrategyCometV3: shares=0");
        _mint(onBehalfOf, shares);
    }

    /// @notice Burn `shares` and withdraw the proportional amount of USDC from Comet to `to`.
    /// @dev Only the Vault may call this.
    function withdraw(uint256 shares, address to) external onlyVault returns (uint256 assets) {
        require(shares > 0, "StrategyCometV3: shares=0");
        require(to != address(0), "StrategyCometV3: to=0");

        uint256 supplyShares = totalSupply();
        require(supplyShares > 0, "StrategyCometV3: no-shares");

        uint256 currentAssets = totalAssets();
        // Pro-rata assets corresponding to the burned shares.
        assets = (shares * currentAssets) / supplyShares;
        require(assets > 0, "StrategyCometV3: assets=0");

        // Burn shares from the Vault (which should be the holder).
        _burn(msg.sender, shares);

        // Withdraw from Comet and send USDC to `to`.
        comet.withdraw(address(usdc), assets);
        usdc.safeTransfer(to, assets);
    }
}
