// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/erc4337/NOVISAccountFactory.sol";
import "../src/erc4337/NOVISPaymaster.sol";

contract DeployERC4337 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Your existing NOVIS token address
        address novisToken = 0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6;
        
        // ERC-4337 EntryPoint on Base (official)
        address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        
        console.log("Deploying from:", deployer);
        console.log("NOVIS Token:", novisToken);
        console.log("EntryPoint:", entryPoint);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Account Factory
        NOVISAccountFactory factory = new NOVISAccountFactory(
            entryPoint,
            novisToken
        );
        console.log("AccountFactory deployed at:", address(factory));
        
        // Deploy Paymaster
        NOVISPaymaster paymaster = new NOVISPaymaster(
            entryPoint,
            novisToken,
            deployer // initial owner
        );
        console.log("Paymaster deployed at:", address(paymaster));
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Complete ===");
        console.log("Next steps:");
        console.log("1. Fund Paymaster with ETH: paymaster.depositETH()");
        console.log("2. Create test account: factory.createAccount()");
        console.log("3. Test transactions");
    }
}
