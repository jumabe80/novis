// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./NOVISSmartAccountV4.sol";

contract NOVISAccountFactoryV4 {
    address public immutable accountImplementation;
    address public immutable entryPoint;
    address public immutable novisToken;
    
    mapping(address => bool) public isAccount;
    address[] public accounts;
    
    event AccountCreated(address indexed account, address indexed owner, uint256 dailyLimit);
    
    constructor(address _entryPoint, address _novisToken) {
        accountImplementation = address(new NOVISSmartAccountV4());
        entryPoint = _entryPoint;
        novisToken = _novisToken;
    }
    
    function createAccount(
        address owner,
        uint256 dailyLimit,
        bytes32 salt
    ) external returns (address account) {
        bytes memory initData = abi.encodeWithSelector(
            NOVISSmartAccountV4.initialize.selector,
            owner,
            entryPoint,
            novisToken,
            dailyLimit
        );
        
        bytes memory proxyCode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(accountImplementation, initData)
        );
        
        bytes32 fullSalt = keccak256(abi.encodePacked(owner, salt));
        
        assembly {
            account := create2(0, add(proxyCode, 0x20), mload(proxyCode), fullSalt)
        }
        
        require(account != address(0), "Failed to create account");
        
        isAccount[account] = true;
        accounts.push(account);
        
        emit AccountCreated(account, owner, dailyLimit);
        return account;
    }
    
    function accountCount() external view returns (uint256) {
        return accounts.length;
    }
    
    function getAccountsByOwner(address owner) external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < accounts.length; i++) {
            if (NOVISSmartAccountV4(payable(accounts[i])).owner() == owner) {
                count++;
            }
        }
        
        address[] memory userAccounts = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < accounts.length; i++) {
            if (NOVISSmartAccountV4(payable(accounts[i])).owner() == owner) {
                userAccounts[index] = accounts[i];
                index++;
            }
        }
        
        return userAccounts;
    }
}
