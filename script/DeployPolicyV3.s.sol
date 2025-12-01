// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ReservePolicyV3} from "src/policy/ReservePolicyV3.sol";

contract DeployPolicyV3 is Script {
    function run() external {
        address OWNER = 0x685F3040003E20Bf09488C8B9354913a00627f7a; // OPS
        address VAULT = 0xdA1AB616384cc6D05e3d7401063183436e3D847F; // Vault (mainnet)
        address EUSD  = 0x4878fF54f1f87162500b5d7091075e441018ff6C; // EUSD (mainnet)
        address USDC  = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC (Base)
        address STRAT = 0x73d4d4B26ED5Bb57cE8B1b65B4C2C33507e8c23b; // StrategyCometV2

        vm.startBroadcast();
        ReservePolicyV3 p = new ReservePolicyV3(OWNER, VAULT, EUSD, USDC, STRAT);
        console2.log("PolicyV3 deployed:", address(p));
        vm.stopBroadcast();
    }
}
