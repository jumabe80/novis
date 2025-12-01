// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {MockComet} from "../contracts/MockComet.sol";
import {StrategyCometV3, ICometLike} from "../contracts/StrategyCometV3.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StrategyCometV3Test is Test {
    MockUSDC usdc;
    MockComet comet;
    StrategyCometV3 strat;

    address vault;

    function setUp() public {
        // For tests, we let this contract act as the Vault.
        vault = address(this);

        usdc = new MockUSDC();
        comet = new MockComet(address(usdc));

        strat = new StrategyCometV3(
            address(usdc),
            address(comet),
            vault
        );
    }

    function testDepositAndWithdraw() public {
        uint256 amount = 1_000e18;

        // Mint USDC to "vault" (this contract) and approve the strategy.
        usdc.mint(vault, amount);
        usdc.approve(address(strat), amount);

        // Vault deposits into the strategy (which supplies to Comet).
        uint256 shares = strat.deposit(amount, vault);
        assertEq(shares, amount, "shares should match amount on first deposit");

        // Strategy TVL and Comet accounting should match deposit.
        assertEq(strat.totalAssets(), amount, "totalAssets after deposit");
        assertEq(comet.balanceOf(address(strat)), amount, "comet balance after deposit");
        assertEq(strat.balanceOf(vault), amount, "vault share balance");

        // Withdraw half of the shares.
        uint256 halfShares = amount / 2;
        uint256 assetsOut = strat.withdraw(halfShares, vault);

        assertEq(assetsOut, amount / 2, "assets out should be proportional");
        assertEq(usdc.balanceOf(vault), amount / 2, "vault should get half back");
        assertEq(strat.balanceOf(vault), amount - halfShares, "vault shares reduced");
    }

    function testDonateIncreasesTotalAssets() public {
        uint256 amount = 1_000e18;

        // Initial deposit.
        usdc.mint(vault, amount);
        usdc.approve(address(strat), amount);
        strat.deposit(amount, vault);

        // Simulate yield: someone donates extra USDC into Comet.
        uint256 yieldAmount = 100e18;
        usdc.mint(address(this), yieldAmount);
        usdc.approve(address(comet), yieldAmount);
        comet.donate(yieldAmount);

        // totalAssets should now be principal + "yield".
        assertEq(
            strat.totalAssets(),
            amount + yieldAmount,
            "totalAssets should include donated yield"
        );
    }
}
