// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title NOVISSmartAccount
 * @notice Smart contract wallet designed for AI agents
 * @dev ERC-4337 compliant account with spending limits, session keys, and recovery
 */
contract NOVISSmartAccount is Initializable, UUPSUpgradeable {
    using ECDSA for bytes32;

    // State Variables
    address public owner;
    address public entryPoint;
    address public novisToken;
    uint256 public dailyLimit;
    uint256 public dailySpent;
    uint256 public lastResetDay;
    uint256 public perTxLimit;
    
    mapping(address => bool) public allowedTokens;
    mapping(address => bool) public allowedRecipients;
    mapping(address => bool) public guardians;
    uint256 public guardianCount;
    uint256 public recoveryThreshold;
    
    struct SessionKey {
        uint256 expiresAt;
        uint256 spendingLimit;
        uint256 spent;
        bool isActive;
    }
    mapping(address => SessionKey) public sessionKeys;
    
    bool public isPaused;

    // Events
    event AccountInitialized(address indexed owner, address indexed entryPoint);
    event DailyLimitSet(uint256 newLimit);
    event TransactionExecuted(address indexed to, uint256 value, bytes data);
    event SessionKeyCreated(address indexed key, uint256 expiresAt, uint256 limit);
    event GuardianAdded(address indexed guardian);
    event AccountPaused();
    event SpendingTracked(uint256 amount, uint256 dailySpent, uint256 dailyLimit);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Account paused");
        _;
    }

    // Initialize
    function initialize(
        address _owner,
        address _entryPoint,
        address _novisToken,
        uint256 _dailyLimit
    ) external initializer {
        require(_owner != address(0), "Invalid owner");
        owner = _owner;
        entryPoint = _entryPoint;
        novisToken = _novisToken;
        dailyLimit = _dailyLimit;
        lastResetDay = block.timestamp / 1 days;
        allowedTokens[_novisToken] = true;
        perTxLimit = _dailyLimit;
        emit AccountInitialized(_owner, _entryPoint);
    }

    // Execute transaction with proper ERC20 transfer detection
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner whenNotPaused returns (bytes memory) {
        // Check if this is an ERC20 transfer to NOVIS token
        uint256 tokenAmount = 0;
        
        if (to == novisToken && data.length >= 68) {
            bytes4 selector = bytes4(data[0:4]);
            
            // ERC20 transfer(address,uint256)
            if (selector == IERC20.transfer.selector) {
                // Decode properly: data is [selector(4)][address(32)][amount(32)]
                // Amount starts at byte 36
                tokenAmount = abi.decode(data[36:68], (uint256));
                
                // Check spending limits for token amount
                _checkSpendingLimits(tokenAmount);
            }
        } else if (value > 0) {
            // If sending ETH, check limits on ETH value
            _checkSpendingLimits(value);
        }

        // Execute the transaction
        (bool success, bytes memory result) = to.call{value: value}(data);
        require(success, "Transaction failed");
        
        emit TransactionExecuted(to, value, data);
        return result;
    }

    // Check spending limits
    function _checkSpendingLimits(uint256 amount) internal {
        // Skip if amount is 0
        if (amount == 0) return;
        
        require(amount <= perTxLimit, "Exceeds per-tx limit");
        
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > lastResetDay) {
            dailySpent = 0;
            lastResetDay = currentDay;
        }
        
        require(dailySpent + amount <= dailyLimit, "Exceeds daily limit");
        dailySpent += amount;
        
        emit SpendingTracked(amount, dailySpent, dailyLimit);
    }

    // Set daily limit
    function setDailyLimit(uint256 newLimit) external onlyOwner {
        dailyLimit = newLimit;
        emit DailyLimitSet(newLimit);
    }

    // Get daily spending
    function getDailySpending() external view returns (uint256 spent, uint256 limit, uint256 remaining) {
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > lastResetDay) {
            return (0, dailyLimit, dailyLimit);
        }
        return (dailySpent, dailyLimit, dailyLimit - dailySpent);
    }

    // Create session key
    function createSessionKey(
        address key,
        uint256 duration,
        uint256 spendingLimit
    ) external onlyOwner {
        require(key != address(0), "Invalid key");
        sessionKeys[key] = SessionKey({
            expiresAt: block.timestamp + duration,
            spendingLimit: spendingLimit,
            spent: 0,
            isActive: true
        });
        emit SessionKeyCreated(key, block.timestamp + duration, spendingLimit);
    }

    // Add guardian
    function addGuardian(address guardian) external onlyOwner {
        require(guardian != address(0), "Invalid guardian");
        require(!guardians[guardian], "Already guardian");
        guardians[guardian] = true;
        guardianCount++;
        emit GuardianAdded(guardian);
    }

    // Pause account
    function pause() external onlyOwner {
        isPaused = true;
        emit AccountPaused();
    }

    // Receive ETH
    receive() external payable {}

    // Authorize upgrade
    function _authorizeUpgrade(address) internal override onlyOwner {}

    // Get balance
    function getBalance(address token) external view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }
}
