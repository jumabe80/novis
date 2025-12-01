// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NOVIS v2 Token
 * @notice ERC20 token with owner-controlled minting
 * @dev Owner (VaultV3) can mint. Anyone can burn their own tokens.
 *      Ownership is transferable for future upgrades.
 */
contract NOVISv2 is ERC20, ERC20Burnable, Ownable {
    
    constructor(address initialOwner) 
        ERC20("NOVIS", "NVS") 
        Ownable(initialOwner) 
    {
        require(initialOwner != address(0), "owner zero");
    }

    /**
     * @notice Mint new tokens (only owner - VaultV3)
     * @param to Recipient address
     * @param amount Amount to mint (18 decimals)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Transfer ownership to new address
     * @dev Inherited from Ownable - allows VaultV3 to transfer token ownership
     *      This ensures we can upgrade/migrate if needed
     */
    // transferOwnership(address newOwner) - inherited from Ownable
}
