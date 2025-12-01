// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20}   from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EUSD is ERC20, Ownable {
    constructor() ERC20("EVO Dollar", "EUSD") Ownable(msg.sender) {}

    /// @dev 18 decimals by default in ERC20
    function mint(address to, uint256 amount18d) external onlyOwner {
        _mint(to, amount18d);
    }

    function burn(uint256 amount18d) external {
        _burn(msg.sender, amount18d);
    }

    function burnFrom(address from, uint256 amount18d) external {
        uint256 currentAllowance = allowance(from, msg.sender);
        require(currentAllowance >= amount18d, "allowance");
        _approve(from, msg.sender, currentAllowance - amount18d);
        _burn(from, amount18d);
    }
}
