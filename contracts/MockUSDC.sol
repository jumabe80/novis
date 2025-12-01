// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Mock USDC (6 decimals), owner-mintable.
 * Uses OZ v5 Ownable() pattern.
 */
contract MockUSDC is ERC20, Ownable {
    constructor(address initialOwner) ERC20("Mock USDC", "USDC") Ownable(initialOwner) {
        _transferOwnership(initialOwner);
}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
