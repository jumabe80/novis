// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/EUSD.sol";

contract EUSDTest is Test {
    EUSD token;

    function setUp() public {
        token = new EUSD();
    }

    function testMintAndBurn() public {
        token.mint(address(this), 100e18);
        assertEq(token.balanceOf(address(this)), 100e18);
        token.burn(40e18);
        assertEq(token.balanceOf(address(this)), 60e18);
    }
}
