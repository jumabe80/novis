// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/EUSD.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        EUSD token = new EUSD();
        vm.stopBroadcast();
        console2.log("EUSD deployed at:", address(token));
    }
}
