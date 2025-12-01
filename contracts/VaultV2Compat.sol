// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VaultV2.sol";

contract VaultV2Compat is VaultV2 {
    constructor(address _usdc, address _eusd, address _owner)
        VaultV2(_usdc, _eusd, _owner)
    {}

    // Policy expects this signature. We delegate to the existing no-arg view.
    function strategyShares(address) external view returns (uint256) {
        return strategyShares();
    }
}
