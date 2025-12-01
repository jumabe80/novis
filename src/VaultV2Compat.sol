// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/VaultV2.sol";

interface IERC20Mini { function totalSupply() external view returns (uint256); }

contract VaultV2Compat is VaultV2 {
    constructor(address _usdc, address _eusd, address _owner)
        VaultV2(_usdc, _eusd, _owner)
    {}

    // Policy expects this signature; delegate to existing no-arg view.
    function strategyShares(address) external view returns (uint256) {
        return strategyShares();
    }

    // Policy expects vault.totalSupply() to reflect EUSD supply (18d).
    function totalSupply() external view returns (uint256) {
        return eusd.totalSupply();
    }
}
