// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/erc4337/NOVISAccountFactoryV4.sol";

contract DeployV4 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address novisToken = 0x6AF5e612Fd96Abf58086d30A12b5d46Faa3581a6;
        address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        
        console.log("Deploying V4 (ERC-4337 compliant)");
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        NOVISAccountFactoryV4 factory = new NOVISAccountFactoryV4(entryPoint, novisToken);
        
        console.log("Factory V4:", address(factory));
        console.log("Implementation V4:", factory.accountImplementation());
        
        vm.stopBroadcast();
    }
}
