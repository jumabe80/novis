// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
interface IComet { function balanceOf(address) external view returns (uint256); }
interface IERC20 { function balanceOf(address) external view returns (uint256); }
contract StrategyComet { // minimal type hints so we can log the address after create2
    constructor(address,address,address) {}
}

import {StrategyComet as RealStrategy} from "contracts/StrategyComet.sol";

contract DeployStrategyComet is Script {
    function run() external {
        address USDC  = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
        address COMET = 0xb125E6687d4313864e53df431d5425969c15Eb2F; // Comet USDC (Base)
        address VAULT = 0xdA1AB616384cc6D05e3d7401063183436e3D847F; // your Vault

        vm.startBroadcast();
        RealStrategy s = new RealStrategy(USDC, COMET, VAULT);
        console2.log("StrategyComet deployed:", address(s));
        vm.stopBroadcast();
    }
}
