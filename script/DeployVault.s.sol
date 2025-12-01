// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {VaultV2Compat} from "src/VaultV2Compat.sol";

contract DeployVault is Script {
    function run() external {
        address USDC  = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base mainnet USDC
        address EUSD  = 0x4878fF54f1f87162500b5d7091075e441018ff6C; // your freshly deployed EUSD
        address OWNER = 0x685F3040003E20Bf09488C8B9354913a00627f7a; // OPS (temp)

        vm.startBroadcast();
        VaultV2Compat vault = new VaultV2Compat(USDC, EUSD, OWNER);
        console2.log("Vault deployed:", address(vault));
        vm.stopBroadcast();
    }
}
