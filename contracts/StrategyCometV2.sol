// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StrategyComet as Base} from "contracts/StrategyComet.sol";

// Thin extension: same behavior, plus the asset() view OZ/Vault expects.
contract StrategyCometV2 is Base {
    constructor(address usdc, address comet, address vault) Base(usdc, comet, vault) {}

    // Vault guard requires this. Return the USDC asset address.
    function asset() external view returns (address) {
        return address(USDC); // Base exposes USDC() getter; matches what we validated earlier.
    }
}
