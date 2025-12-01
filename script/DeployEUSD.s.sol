// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {EUSDv3Premint} from "src/token/EUSDv3Premint.sol";

contract DeployEUSD is Script {
    function run() external {
        address OPS = 0x685F3040003E20Bf09488C8B9354913a00627f7a;
        vm.startBroadcast();
        EUSDv3Premint eusd = new EUSDv3Premint(OPS, address(0), 0);
        console2.log("EUSD deployed:", address(eusd));
        vm.stopBroadcast();
    }
}
