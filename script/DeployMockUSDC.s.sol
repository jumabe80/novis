// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../contracts/MockUSDC.sol";

contract DeployMockUSDC is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);
        MockUSDC usdc = new MockUSDC(deployer);

        // Pre-mint 1,000,000 USDC (6 decimals) to the deployer for testing
        usdc.mint(deployer, 1_000_000 * 1e6);
        vm.stopBroadcast();

        console2.log("MockUSDC deployed at:", address(usdc));
        console2.log("Deployer (owner):", deployer);
    }
}
