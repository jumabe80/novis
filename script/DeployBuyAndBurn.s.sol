// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/FortUSDBuyAndBurn.sol";

contract DeployBuyAndBurn is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Configuration
        address owner = 0x4709280aef7A496EA84e72dB3CAbAd5e324d593e;      // SAFE multisig
        address vault = 0x8DCa98C72f457793A901813802F04e74d4CBFF05;      // VaultV2
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;       // USDC on Base
        address novis = 0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6;      // NOVIS token
        address router = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;     // Aerodrome Router
        address factory = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;    // Aerodrome Factory
        
        // Parameters
        bool stable = false;                    // Volatile pool
        uint16 triggerBufferBps = 1000;         // 10% buffer required (lower for testing)
        uint16 maxBuyBufferPctBps = 5000;       // Max 50% of buffer per tx
        uint32 cooldown = 1 days;               // 1 day between burns
        
        vm.startBroadcast(deployerPrivateKey);
        
        FortUSDBuyAndBurn buyAndBurn = new FortUSDBuyAndBurn(
            owner,
            vault,
            usdc,
            novis,
            router,
            factory,
            stable,
            triggerBufferBps,
            maxBuyBufferPctBps,
            cooldown
        );
        
        console.log("BuyAndBurn deployed at:", address(buyAndBurn));
        console.log("  owner:", owner);
        console.log("  vault:", vault);
        console.log("  novis:", novis);
        console.log("  router:", router);
        console.log("  triggerBufferBps:", triggerBufferBps);
        console.log("  maxBuyBufferPctBps:", maxBuyBufferPctBps);
        console.log("  cooldown:", cooldown);
        
        vm.stopBroadcast();
    }
}
