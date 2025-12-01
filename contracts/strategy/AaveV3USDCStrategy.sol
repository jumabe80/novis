// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {IPool, IScaledBalanceToken} from "../vendor/IAaveV3Minimal.sol";

/**
 * AaveV3USDCStrategy
 * - Asset: USDC (6 decimals)
 * - Shares: 18 decimals
 * - totalAssets() reads aToken balance (principal+interest)
 *
 * Assumptions:
 * - Vault calls deposit(amount,onBehalfOf) after transferring USDC to this strategy (via transferFrom).
 * - Strategy supplies USDC to Aave v3 IPool and receives aTokens.
 * - Withdraw burns shares and pulls USDC from Aave to the `to` address.
 */
contract AaveV3USDCStrategy is ERC20, IStrategy {
    IERC20 public immutable usdc; // 6 decimals
    IPool public immutable pool; // Aave v3 IPool
    IScaledBalanceToken public immutable aToken; // the USDC aToken for this market

    constructor(address _usdc, address _pool, address _aToken) ERC20("Aave v3 USDC Strategy Share", "avUSDC-sh") {
        require(_usdc != address(0) && _pool != address(0) && _aToken != address(0), "zero");
        usdc = IERC20(_usdc);
        pool = IPool(_pool);
        aToken = IScaledBalanceToken(_aToken);
        // pre-approve pool for convenience (infinite approve)
        IERC20(_usdc).approve(_pool, type(uint256).max);
    }

    // IStrategy
    function asset() external view returns (address) {
        return address(usdc);
    }

    function totalAssets() public view returns (uint256) {
        // In Aave v3, aToken.balanceOf(user) returns the interest-accruing balance in asset units
        return aToken.balanceOf(address(this));
    }

    function assetsPerShare() public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 1e18; // initial price = 1
        // convert assets (6d) to 18d, then divide by shares
        return (totalAssets() * 1e12) * 1e18 / supply;
    }

    /**
     * deposit:
     * - Vault calls this after approving the strategy to pull USDC from the Vault.
     * - Strategy pulls `amount` from msg.sender (expected: Vault), supplies to Aave, then mints shares to onBehalfOf.
     */
    function deposit(uint256 amount, address onBehalfOf) external returns (uint256 shares) {
        require(amount > 0, "amount=0");
        require(onBehalfOf != address(0), "onBehalfOf=0");

        // Pull USDC in (from Vault)
        require(usdc.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        // Supply to Aave (referral=0)
        pool.supply(address(usdc), amount, address(this), 0);

        // Mint shares at current price
        uint256 pps = assetsPerShare(); // 18d
        uint256 assets18 = amount * 1e12; // 6d -> 18d
        shares = (assets18 * 1e18) / pps; // keep 18d math
        _mint(onBehalfOf, shares);
    }

    /**
     * withdraw:
     * - Burn `shares` and redeem proportional USDC from Aave directly to `to`.
     */
    function withdraw(uint256 shares, address to) external returns (uint256 assetsOut) {
        require(shares > 0, "shares=0");
        require(to != address(0), "to=0");

        uint256 pps = assetsPerShare(); // 18d
        uint256 assets18 = shares * pps / 1e18; // 18d
        assetsOut = assets18 / 1e12; // back to 6d

        _burn(msg.sender, shares);

        // withdraw from Aave to `to` (0 == withdraw all aToken if balance < amount; we pass exact amount)
        uint256 withdrawn = pool.withdraw(address(usdc), assetsOut, to);
        require(withdrawn == assetsOut, "partial withdraw");
    }
}
