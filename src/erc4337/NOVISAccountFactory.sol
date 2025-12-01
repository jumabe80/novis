// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./NOVISSmartAccount.sol";

/**
 * @title NOVISAccountFactory
 * @notice Factory for creating NOVIS Smart Accounts
 */
contract NOVISAccountFactory {
    
    address public immutable accountImplementation;
    address public immutable entryPoint;
    address public immutable novisToken;
    
    mapping(address => bool) public isAccount;
    address[] public accounts;

    event AccountCreated(address indexed account, address indexed owner, uint256 dailyLimit);

    constructor(address _entryPoint, address _novisToken) {
        require(_entryPoint != address(0), "Invalid entryPoint");
        require(_novisToken != address(0), "Invalid NOVIS token");
        entryPoint = _entryPoint;
        novisToken = _novisToken;
        accountImplementation = address(new NOVISSmartAccount());
    }

    function createAccount(
        address owner,
        uint256 dailyLimit,
        bytes32 salt
    ) external returns (address account) {
        bytes32 fullSalt = keccak256(abi.encodePacked(owner, dailyLimit, salt));
        
        account = address(new ERC1967Proxy{salt: fullSalt}(
            accountImplementation,
            abi.encodeWithSelector(
                NOVISSmartAccount.initialize.selector,
                owner,
                entryPoint,
                novisToken,
                dailyLimit
            )
        ));

        isAccount[account] = true;
        accounts.push(account);
        emit AccountCreated(account, owner, dailyLimit);
    }

    function accountCount() external view returns (uint256) {
        return accounts.length;
    }

    function getAccountsByOwner(address owner) external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < accounts.length; i++) {
            if (NOVISSmartAccount(payable(accounts[i])).owner() == owner) {
                count++;
            }
        }

        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < accounts.length; i++) {
            if (NOVISSmartAccount(payable(accounts[i])).owner() == owner) {
                result[index] = accounts[i];
                index++;
            }
        }
        return result;
    }
}
