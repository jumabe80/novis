// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal Comet-like mock for testing strategies on Base Sepolia.
/// - supply(asset, amount): pulls ERC20 from caller into this contract
/// - withdraw(asset, amount): sends ERC20 from this contract to caller
/// - balanceOf(account): returns principal + pro-rata share of any donated yield
///
/// This is ONLY for testing, not for mainnet.
contract MockComet {
    using SafeERC20 for IERC20;

    IERC20 public immutable baseAsset; // e.g. mock USDC

    // Principal supplied by each account
    mapping(address => uint256) internal principal;
    // Total principal supplied by all accounts
    uint256 internal totalPrincipal;

    constructor(address _baseAsset) {
        require(_baseAsset != address(0), "base=0");
        baseAsset = IERC20(_baseAsset);
    }

    /// @notice Mimics Comet's supply: pull tokens from caller and credit their principal.
    function supply(address asset, uint256 amount) external {
        require(asset == address(baseAsset), "wrong-asset");
        require(amount > 0, "amount=0");
        baseAsset.safeTransferFrom(msg.sender, address(this), amount);
        principal[msg.sender] += amount;
        totalPrincipal += amount;
    }

    /// @notice Mimics Comet's withdraw: debit caller's principal and send tokens out.
    function withdraw(address asset, uint256 amount) external {
        require(asset == address(baseAsset), "wrong-asset");
        require(amount > 0, "amount=0");

        // Compute current "balance" including yield.
        uint256 bal = balanceOf(msg.sender);
        require(bal >= amount, "insufficient");

        // Figure out how much principal to burn for this withdrawal.
        // If there is yield, we reduce principal proportionally.
        if (totalPrincipal > 0) {
            uint256 totalUnderlying = baseAsset.balanceOf(address(this));
            // principalToBurn = amount * totalPrincipal / totalUnderlying
            uint256 principalToBurn = (amount * totalPrincipal) / totalUnderlying;
            if (principalToBurn > principal[msg.sender]) {
                principalToBurn = principal[msg.sender];
            }
            principal[msg.sender] -= principalToBurn;
            totalPrincipal -= principalToBurn;
        }

        baseAsset.safeTransfer(msg.sender, amount);
    }

    /// @notice Comet-style balanceOf: principal plus pro-rata share of any donated yield.
    function balanceOf(address account) public view returns (uint256) {
        uint256 p = principal[account];
        if (p == 0) return 0;
        uint256 tp = totalPrincipal;
        if (tp == 0) return 0;

        uint256 totalUnderlying = baseAsset.balanceOf(address(this));
        // User's share = principal * totalUnderlying / totalPrincipal
        return (p * totalUnderlying) / tp;
    }

    /// @notice Helper to simulate yield by donating baseAsset directly to this contract.
    /// In a real Comet, yield is via interest; here we just increase TVL.
    function donate(uint256 amount) external {
        require(amount > 0, "amount=0");
        baseAsset.safeTransferFrom(msg.sender, address(this), amount);
    }
}
