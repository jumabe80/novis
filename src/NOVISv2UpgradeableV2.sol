// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title NOVISv2UpgradeableV2
 * @notice NOVIS token with native gasless support for AI agents & humans
 * @dev Fee: FREE < 10 NOVIS, configurable % ≥ 10 NOVIS (default 0.1%)
 *      Users sign, relayers execute, ZERO ETH needed
 */
contract NOVISv2UpgradeableV2 is 
    ERC20Upgradeable, 
    ERC20BurnableUpgradeable, 
    ERC20PermitUpgradeable,
    OwnableUpgradeable, 
    UUPSUpgradeable 
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Fee Configuration
    uint256 public feeThreshold;
    uint16 public feePercentageBps;
    bool public feesEnabled;
    address public treasury;
    
    // Meta-tx Support
    mapping(address => uint256) public metaTxNonces;
    bool public anyoneCanRelay;
    
    // Exemptions & Stats
    mapping(address => bool) public feeExempt;
    uint256 public totalFeesCollected;
    uint256 public totalMetaTxRelayed;
    
    uint256[42] private __gap;
    
    event FeeCollected(address indexed from, address indexed to, uint256 amount, uint256 fee);
    event FeeParamsUpdated(uint256 threshold, uint16 feeBps, bool enabled);
    event TreasuryUpdated(address indexed treasury);
    event FeeExemptUpdated(address indexed account, bool exempt);
    event MetaTransferExecuted(address indexed from, address indexed to, uint256 amount, address indexed relayer);

    bytes32 public constant META_TRANSFER_TYPEHASH = keccak256(
        "MetaTransfer(address from,address to,uint256 amount,uint256 nonce,uint256 deadline)"
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address initialOwner) public initializer {
        __ERC20_init("NOVIS", "NVS");
        __ERC20Burnable_init();
        __ERC20Permit_init("NOVIS");
        __Ownable_init(initialOwner);
    }
    
    function initializeV2(address _treasury) external onlyOwner {
        require(feeThreshold == 0, "Already initialized");
        require(_treasury != address(0), "Zero treasury");
        feeThreshold = 10 ether;
        feePercentageBps = 10;
        feesEnabled = true;
        treasury = _treasury;
        anyoneCanRelay = true;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        if (_shouldSkipFee(from, to, amount)) {
            super._update(from, to, amount);
            return;
        }
        
        uint256 fee = (amount * feePercentageBps) / 10000;
        uint256 netAmount = amount - fee;
        
        if (fee > 0 && treasury != address(0)) {
            super._update(from, treasury, fee);
            totalFeesCollected += fee;
            emit FeeCollected(from, to, amount, fee);
        }
        
        super._update(from, to, netAmount);
    }

    function _shouldSkipFee(address from, address to, uint256 amount) internal view returns (bool) {
        return from == address(0) || 
               to == address(0) || 
               !feesEnabled || 
               feeExempt[from] || 
               feeExempt[to] || 
               amount < feeThreshold;
    }

    /**
     * @notice Execute gasless transfer - AI agents & humans sign, anyone relays
     */
    function metaTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external returns (bool) {
        require(block.timestamp <= deadline, "Expired");
        require(anyoneCanRelay || feeExempt[msg.sender], "Not relayer");
        
        uint256 nonce = metaTxNonces[from]++;
        
        bytes32 structHash = keccak256(abi.encode(
            META_TRANSFER_TYPEHASH, from, to, amount, nonce, deadline
        ));
        
        address signer = _hashTypedDataV4(structHash).recover(signature);
        require(signer == from, "Invalid sig");
        
        _transfer(from, to, amount);
        
        totalMetaTxRelayed++;
        emit MetaTransferExecuted(from, to, amount, msg.sender);
        
        return true;
    }

    function getMetaTxNonce(address account) external view returns (uint256) {
        return metaTxNonces[account];
    }

    function getMetaTransferDigest(
        address from, address to, uint256 amount, uint256 nonce, uint256 deadline
    ) external view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            META_TRANSFER_TYPEHASH, from, to, amount, nonce, deadline
        )));
    }

    function calculateTransferFee(
        address from, address to, uint256 amount
    ) external view returns (uint256 fee, uint256 netAmount) {
        if (_shouldSkipFee(from, to, amount)) return (0, amount);
        fee = (amount * feePercentageBps) / 10000;
        netAmount = amount - fee;
    }
    
    function setFeeParams(uint256 _threshold, uint16 _feeBps, bool _enabled) external onlyOwner {
        require(_feeBps <= 500, "Fee > 5%");
        feeThreshold = _threshold;
        feePercentageBps = _feeBps;
        feesEnabled = _enabled;
        emit FeeParamsUpdated(_threshold, _feeBps, _enabled);
    }
    
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Zero");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }
    
    function setFeeExempt(address account, bool exempt) external onlyOwner {
        feeExempt[account] = exempt;
        emit FeeExemptUpdated(account, exempt);
    }
    
    function setFeeExemptBatch(address[] calldata accounts, bool exempt) external onlyOwner {
        for (uint i = 0; i < accounts.length; i++) {
            feeExempt[accounts[i]] = exempt;
            emit FeeExemptUpdated(accounts[i], exempt);
        }
    }

    function setAnyoneCanRelay(bool allowed) external onlyOwner {
        anyoneCanRelay = allowed;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}
