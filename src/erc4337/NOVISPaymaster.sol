// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title NOVISPaymaster
 * @notice Paymaster that sponsors gas for NOVIS transactions
 * @dev Fee structure: Free <$10, 0.05% ≥$10
 */
contract NOVISPaymaster is Ownable {
    using SafeERC20 for IERC20;

    address public immutable entryPoint;
    IERC20 public immutable novisToken;
    
    uint256 public freeThreshold = 10 ether; // $10 in NOVIS
    uint256 public feePercentageBps = 50; // 0.05%
    
    uint256 public totalGasSponsored;
    uint256 public totalFeesCollected;
    uint256 public ethBalance;

    event GasSponsored(address indexed account, uint256 amount, uint256 gasUsed, bool wasFree);
    event FeeCollected(address indexed account, uint256 novisAmount, uint256 feeAmount);
    event ThresholdUpdated(uint256 newThreshold);
    event ETHDeposited(uint256 amount);

    constructor(
        address _entryPoint, 
        address _novisToken,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_entryPoint != address(0), "Invalid entryPoint");
        require(_novisToken != address(0), "Invalid NOVIS");
        entryPoint = _entryPoint;
        novisToken = IERC20(_novisToken);
    }

    modifier onlyEntryPoint() {
        require(msg.sender == entryPoint, "Not EntryPoint");
        _;
    }

    function setFreeThreshold(uint256 newThreshold) external onlyOwner {
        freeThreshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    function setFeePercentage(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 100, "Fee too high");
        feePercentageBps = newFeeBps;
    }

    function depositETH() external payable onlyOwner {
        ethBalance += msg.value;
        emit ETHDeposited(msg.value);
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount <= ethBalance, "Insufficient balance");
        ethBalance -= amount;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    function withdrawNOVIS(address to, uint256 amount) external onlyOwner {
        novisToken.safeTransfer(to, amount);
    }

    function calculateFee(uint256 amount) external view returns (uint256 fee, bool isFree) {
        if (amount < freeThreshold) {
            return (0, true);
        }
        return ((amount * feePercentageBps) / 10000, false);
    }

    function getStats() external view returns (
        uint256 _ethBalance,
        uint256 _totalGasSponsored,
        uint256 _totalFeesCollected,
        uint256 _freeThreshold,
        uint256 _feePercentageBps
    ) {
        return (ethBalance, totalGasSponsored, totalFeesCollected, freeThreshold, feePercentageBps);
    }

    receive() external payable {
        ethBalance += msg.value;
    }
}
