// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/StrategyCometV3.sol";

contract DeployNOVISStrategy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // NOVIS VaultV2
        address vault = 0x8DCa98C72f457793A901813802F04e74d4CBFF05;
        // Base USDC
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        // Compound V3 Comet on Base
        address comet = 0xb125E6687d4313864e53df431d5425969c15Eb2F;
        
        vm.startBroadcast(deployerPrivateKey);
        
        StrategyCometV3 strategy = new StrategyCometV3(usdc, comet, vault);
        
        console.log("StrategyCometV3 deployed at:", address(strategy));
        console.log("  vault:", vault);
        console.log("  usdc:", usdc);
        console.log("  comet:", comet);
        
        vm.stopBroadcast();
    }
}
