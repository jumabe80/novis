// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/EUSD.sol";
import "../contracts/VaultV2.sol";

contract DeployVaultV2 is Script {
    function run() external {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        address usdc = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast();

        // 1) Deploy a fresh EUSD (owner=deployer initially)
        EUSD eusd = new EUSD();

        // 2) Deploy VaultV2; set owner = deployer (so you can run admin calls)
        VaultV2 vault = new VaultV2(usdc, address(eusd), deployer);

        // 3) Give EUSD ownership to the new vault (so only vault can mint/burn)
        eusd.transferOwnership(address(vault));

        vm.stopBroadcast();

        console2.log("EUSD:", address(eusd));
        console2.log("VaultV2:", address(vault));
    }
}
