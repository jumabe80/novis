// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

contract NOVISSmartAccountV4 is Initializable, UUPSUpgradeable, IERC1271 {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public owner;
    address public entryPoint;
    address public novisToken;
    uint256 public dailyLimit;
    uint256 public dailySpent;
    uint256 public lastResetDay;
    uint256 public perTxLimit;
    
    mapping(address => bool) public allowedTokens;
    mapping(address => bool) public guardians;
    uint256 public guardianCount;
    
    struct SessionKey {
        uint256 expiresAt;
        uint256 spendingLimit;
        uint256 spent;
        bool isActive;
    }
    mapping(address => SessionKey) public sessionKeys;
    
    bool public isPaused;

    address public constant TREASURY = 0x4709280aef7A496EA84e72dB3CAbAd5e324d593e;
    uint256 public constant FEE_THRESHOLD = 10 * 1e18; // 10 NOVIS
    uint256 public constant FEE_BPS = 5; // 0.05% = 5 / 10000

    event AccountInitialized(address indexed owner, address indexed entryPoint);
    event DailyLimitSet(uint256 newLimit);
    event TransactionExecuted(address indexed to, uint256 value, bytes data);
    event SessionKeyCreated(address indexed key, uint256 expiresAt, uint256 limit);
    event GuardianAdded(address indexed guardian);
    event AccountPaused();
    event AccountUnpaused();
    event SpendingTracked(uint256 amount, uint256 dailySpent, uint256 dailyLimit);
    event FeeCollected(address indexed from, address indexed treasury, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == entryPoint, "Not EntryPoint");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Account paused");
        _;
    }

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

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        
        // tryRecover returns (address, RecoverError, bytes32)
        (address signer, ECDSA.RecoverError error, ) = hash.tryRecover(userOp.signature);
        
        if (error != ECDSA.RecoverError.NoError || signer != owner) {
            return 1;
        }
        
        // Try to pay prefund, but don't revert if it fails (paymaster covers it)
        if (missingAccountFunds > 0) {
            payable(msg.sender).call{value: missingAccountFunds}("");
        }
        
        return 0;
    }

    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external whenNotPaused returns (bytes memory) {
        require(msg.sender == owner || msg.sender == entryPoint, "Not authorized");
        
        uint256 tokenAmount = 0;
        
        if (to == novisToken && data.length >= 68) {
            bytes4 selector = bytes4(data[0:4]);
            
            if (selector == IERC20.transfer.selector) {
                (address recipient, uint256 amount) = abi.decode(data[4:68], (address, uint256));
                tokenAmount = amount;
                _checkSpendingLimits(tokenAmount);
                
                // Fee collection for transfers >= 10 NOVIS
                if (amount >= FEE_THRESHOLD) {
                    uint256 fee = (amount * FEE_BPS) / 10000;
                    uint256 netAmount = amount - fee;
                    
                    // Transfer fee to treasury
                    (bool feeSuccess,) = novisToken.call(
                        abi.encodeWithSelector(IERC20.transfer.selector, TREASURY, fee)
                    );
                    require(feeSuccess, "Fee transfer failed");
                    emit FeeCollected(address(this), TREASURY, fee);
                    
                    // Transfer net amount to recipient
                    (bool success, bytes memory result) = novisToken.call(
                        abi.encodeWithSelector(IERC20.transfer.selector, recipient, netAmount)
                    );
                    require(success, "Transaction failed");
                    emit TransactionExecuted(to, value, data);
                    return result;
                }
            }
        } else if (value > 0) {
            _checkSpendingLimits(value);
        }

        (bool success, bytes memory result) = to.call{value: value}(data);
        require(success, "Transaction failed");
        
        emit TransactionExecuted(to, value, data);
        return result;
    }

    function _checkSpendingLimits(uint256 amount) internal {
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

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4)
    {
        bytes32 ethHash = hash.toEthSignedMessageHash();
        address signer = ethHash.recover(signature);
        
        if (signer == owner) {
            return 0x1626ba7e;
        }
        return 0xffffffff;
    }

    function setDailyLimit(uint256 newLimit) external onlyOwner {
        dailyLimit = newLimit;
        emit DailyLimitSet(newLimit);
    }

    function getDailySpending() external view returns (uint256 spent, uint256 limit, uint256 remaining) {
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > lastResetDay) {
            return (0, dailyLimit, dailyLimit);
        }
        return (dailySpent, dailyLimit, dailyLimit - dailySpent);
    }

    function createSessionKey(address key, uint256 duration, uint256 spendingLimit) external onlyOwner {
        require(key != address(0), "Invalid key");
        sessionKeys[key] = SessionKey({
            expiresAt: block.timestamp + duration,
            spendingLimit: spendingLimit,
            spent: 0,
            isActive: true
        });
        emit SessionKeyCreated(key, block.timestamp + duration, spendingLimit);
    }

    function addGuardian(address guardian) external onlyOwner {
        require(guardian != address(0), "Invalid guardian");
        require(!guardians[guardian], "Already guardian");
        guardians[guardian] = true;
        guardianCount++;
        emit GuardianAdded(guardian);
    }

    function pause() external onlyOwner {
        isPaused = true;
        emit AccountPaused();
    }

    function unpause() external onlyOwner {
        isPaused = false;
        emit AccountUnpaused();
    }
    function getBalance(address token) external view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    receive() external payable {}

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
