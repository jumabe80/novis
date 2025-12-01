// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/MockStrategy.sol";

contract DeployMockStrategy is Script {
    function run() external {
        address usdc = vm.envAddress("USDC_ADDRESS");
        vm.startBroadcast();
        MockStrategy strat = new MockStrategy(usdc);
        console2.log("MockStrategy deployed at:", address(strat));
        vm.stopBroadcast();
    }
}
