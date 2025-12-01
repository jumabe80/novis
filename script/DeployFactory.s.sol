// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/erc4337/NOVISAccountFactoryV4.sol";

contract DeployFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        address novisToken = 0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85;
        
        vm.startBroadcast(deployerPrivateKey);
        
        NOVISAccountFactoryV4 factory = new NOVISAccountFactoryV4(entryPoint, novisToken);
        
        console.log("Factory:", address(factory));
        console.log("Implementation:", factory.accountImplementation());
        
        vm.stopBroadcast();
    }
}
