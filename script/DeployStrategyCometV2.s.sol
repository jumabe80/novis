// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {StrategyCometV2} from "contracts/StrategyCometV2.sol";

contract DeployStrategyCometV2 is Script {
    function run() external {
        address USDC  = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
        address COMET = 0xb125E6687d4313864e53df431d5425969c15Eb2F; // Base Comet USDC
        address VAULT = 0xdA1AB616384cc6D05e3d7401063183436e3D847F; // Your Vault

        vm.startBroadcast();
        StrategyCometV2 s = new StrategyCometV2(USDC, COMET, VAULT);
        console2.log("StrategyCometV2 deployed:", address(s));
        vm.stopBroadcast();
    }
}
