// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/NOVISv2.sol";
import "../src/VaultV3.sol";
import "../src/StrategyCometV3.sol";

contract DeployNOVISv2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Configuration - Base Mainnet
        address safe = 0x4709280aef7A496EA84e72dB3CAbAd5e324d593e;
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        address comet = 0xb125E6687d4313864e53df431d5425969c15Eb2F;
        address aerodromeRouter = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
        address aerodromeFactory = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
        
        console.log("Deployer:", deployer);
        console.log("SAFE:", safe);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy NOVIS v2 Token (owner: deployer temporarily)
        NOVISv2 novis = new NOVISv2(deployer);
        console.log("1. NOVISv2 deployed:", address(novis));
        
        // Step 2: Deploy VaultV3 (owner: deployer temporarily)
        VaultV3 vault = new VaultV3(
            deployer,           // owner (temporary)
            usdc,
            address(novis),
            aerodromeRouter,
            aerodromeFactory,
            safe                // treasury
        );
        console.log("2. VaultV3 deployed:", address(vault));
        
        // Step 3: Transfer NOVIS ownership to VaultV3
        novis.transferOwnership(address(vault));
        console.log("3. NOVIS ownership transferred to VaultV3");
        
        // Step 4: Deploy StrategyCometV3 (owner: deployer temporarily)
        StrategyCometV3 strategy = new StrategyCometV3(
            deployer,           // owner (temporary)
            address(vault),
            usdc,
            comet
        );
        console.log("4. StrategyCometV3 deployed:", address(strategy));
        
        // Step 5: Configure VaultV3 with strategy
        vault.setStrategy(address(strategy));
        console.log("5. Strategy set on VaultV3");
        
        // Step 6: Transfer Strategy ownership to SAFE
        strategy.transferOwnership(safe);
        console.log("6. Strategy ownership transferred to SAFE");
        
        // Step 7: Transfer VaultV3 ownership to SAFE
        vault.transferOwnership(safe);
        console.log("7. VaultV3 ownership transferred to SAFE");
        
        vm.stopBroadcast();
        
        // Verification
        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("NOVISv2:         ", address(novis));
        console.log("VaultV3:         ", address(vault));
        console.log("StrategyCometV3: ", address(strategy));
        console.log("");
        console.log("=== OWNERSHIP VERIFICATION ===");
        console.log("NOVIS owner:     ", novis.owner(), "(should be VaultV3)");
        console.log("VaultV3 owner:   ", vault.owner(), "(should be SAFE)");
        console.log("Strategy owner:  ", strategy.owner(), "(should be SAFE)");
    }
}
