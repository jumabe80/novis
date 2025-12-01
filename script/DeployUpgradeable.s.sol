// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NOVISv2Upgradeable.sol";
import "../src/VaultV3Upgradeable.sol";
import "../src/StrategyCometV3Upgradeable.sol";

contract DeployUpgradeable is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address safe = 0x4709280aef7A496EA84e72dB3CAbAd5e324d593e;
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        address comet = 0xb125E6687d4313864e53df431d5425969c15Eb2F;
        address aerodromeRouter = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
        address aerodromeFactory = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
        
        console.log("=== DEPLOYING UPGRADEABLE NOVIS ===");
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. NOVIS Token
        NOVISv2Upgradeable novisImpl = new NOVISv2Upgradeable();
        ERC1967Proxy novisProxy = new ERC1967Proxy(address(novisImpl), abi.encodeCall(NOVISv2Upgradeable.initialize, (deployer)));
        console.log("NOVIS Proxy:", address(novisProxy));
        
        // 2. Vault
        VaultV3Upgradeable vaultImpl = new VaultV3Upgradeable();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), abi.encodeCall(VaultV3Upgradeable.initialize, (deployer, usdc, address(novisProxy), aerodromeRouter, aerodromeFactory, safe)));
        console.log("Vault Proxy:", address(vaultProxy));
        
        // 3. Transfer NOVIS ownership to Vault
        NOVISv2Upgradeable(address(novisProxy)).transferOwnership(address(vaultProxy));
        
        // 4. Strategy
        StrategyCometV3Upgradeable strategyImpl = new StrategyCometV3Upgradeable();
        ERC1967Proxy strategyProxy = new ERC1967Proxy(address(strategyImpl), abi.encodeCall(StrategyCometV3Upgradeable.initialize, (deployer, address(vaultProxy), usdc, comet)));
        console.log("Strategy Proxy:", address(strategyProxy));
        
        // 5. Configure & transfer ownership
        VaultV3Upgradeable(payable(address(vaultProxy))).setStrategy(address(strategyProxy));
        StrategyCometV3Upgradeable(payable(address(strategyProxy))).transferOwnership(safe);
        VaultV3Upgradeable(payable(address(vaultProxy))).transferOwnership(safe);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== PROXY ADDRESSES (USE THESE) ===");
        console.log("NOVIS:", address(novisProxy));
        console.log("Vault:", address(vaultProxy));
        console.log("Strategy:", address(strategyProxy));
        console.log("");
        console.log("=== IMPLEMENTATIONS ===");
        console.log("NOVIS Impl:", address(novisImpl));
        console.log("Vault Impl:", address(vaultImpl));
        console.log("Strategy Impl:", address(strategyImpl));
    }
}
