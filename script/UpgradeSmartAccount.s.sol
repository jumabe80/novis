// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/erc4337/NOVISSmartAccount.sol";
import "../src/erc4337/NOVISAccountFactory.sol";

contract UpgradeSmartAccount is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address novisToken = 0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6;
        address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        address paymaster = 0x5cf66c7D045aeedAd3db18bc4951aeF12f8f9d9F;
        
        console.log("Deploying from:", deployer);
        console.log("NOVIS Token:", novisToken);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new AccountFactory with fixed implementation
        NOVISAccountFactory newFactory = new NOVISAccountFactory(
            entryPoint,
            novisToken
        );
        console.log("New Factory deployed at:", address(newFactory));
        console.log("New Implementation at:", newFactory.accountImplementation());
        
        vm.stopBroadcast();
        
        console.log("\n=== Upgrade Complete ===");
        console.log("Old Factory: 0xAc87Df37F988bF6d2486c5EbE34166fCECD77Fcf");
        console.log("New Factory:", address(newFactory));
        console.log("\nNext: Create new account using new factory");
    }
}
