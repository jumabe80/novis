// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVaultLike {
    function totalSupply() external view returns (uint256); // EUSD 18d
    function usdc() external view returns (address); // address of USDC
    function strategy() external view returns (address); // strategy address
    function allocate(uint256 amount) external; // owner-only
    function redeem(uint256 amountEUSD) external; // burns EUSD from caller
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/// @notice Policy planner with on-chain recommendations + safe caps.
///         For now it does NOT need to be the owner. Your keeper reads
///         the recommendation and has your wallet perform the action.
///         Later, you can set this contract as Vault owner and call
///         executeRebalance() to have it act directly.
contract ReservePolicyV2 {
    error NotOwner();
    event ParamsUpdated(uint16 targetBps, uint16 upperBps, uint16 lowerBps);
    event CapsUpdated(uint256 maxAllocPerTx, uint256 maxDeallocPerTx, uint256 dailyAllocCap, uint256 dailyDeallocCap);
    event WindowReset(uint256 at);
    event Recommendation(bytes32 action, uint256 amount);
    event Executed(bytes32 action, uint256 amount);

    address public immutable vault;
    address public immutable usdc;
    address public immutable strategy;
    address public owner;

    uint16 public targetBps; // e.g. 2500 (25%)
    uint16 public upperBps; // e.g. 200  (2% above)
    uint16 public lowerBps; // e.g. 200  (2% below)

    uint256 public maxAllocPerTx; // USDC (6d)
    uint256 public maxDeallocPerTx; // USDC (6d)
    uint256 public dailyAllocCap; // USDC/day
    uint256 public dailyDeallocCap; // USDC/day
    uint256 public windowStart; // unix sec
    uint256 public allocatedToday; // USDC
    uint256 public deallocatedToday; // USDC

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(
        address _vault,
        address _usdc,
        address _strategy,
        uint16 _targetBps,
        uint16 _upperBps,
        uint16 _lowerBps,
        uint256 _maxAllocPerTx,
        uint256 _maxDeallocPerTx,
        uint256 _dailyAllocCap,
        uint256 _dailyDeallocCap
    ) {
        owner = msg.sender;
        vault = _vault;
        usdc = _usdc;
        strategy = _strategy;

        targetBps = _targetBps;
        upperBps = _upperBps;
        lowerBps = _lowerBps;

        maxAllocPerTx = _maxAllocPerTx;
        maxDeallocPerTx = _maxDeallocPerTx;
        dailyAllocCap = _dailyAllocCap;
        dailyDeallocCap = _dailyDeallocCap;

        windowStart = block.timestamp;
    }

    function setOwner(address n) external onlyOwner {
        owner = n;
    }

    function setParams(uint16 _targetBps, uint16 _upperBps, uint16 _lowerBps) external onlyOwner {
        targetBps = _targetBps;
        upperBps = _upperBps;
        lowerBps = _lowerBps;
        emit ParamsUpdated(_targetBps, _upperBps, _lowerBps);
    }

    function setCaps(
        uint256 _maxAllocPerTx,
        uint256 _maxDeallocPerTx,
        uint256 _dailyAllocCap,
        uint256 _dailyDeallocCap
    ) external onlyOwner {
        maxAllocPerTx = _maxAllocPerTx;
        maxDeallocPerTx = _maxDeallocPerTx;
        dailyAllocCap = _dailyAllocCap;
        dailyDeallocCap = _dailyDeallocCap;
        emit CapsUpdated(_maxAllocPerTx, _maxDeallocPerTx, _dailyAllocCap, _dailyDeallocCap);
    }

    function _vaultUsdc() public view returns (uint256) {
        return IERC20(usdc).balanceOf(vault); // 6d
    }

    function _targetUsdc() public view returns (uint256) {
        // totalSupply is EUSD 18d; vault USDC target is supply * targetBps / 10_000, scaled to 6d
        uint256 supply = IVaultLike(vault).totalSupply(); // 18d
        // 18d * bps / 1e4 -> 18d; convert to 6d by / 1e12
        return (supply * targetBps) / 10_000 / 1e12;
    }

    function _resetWindowIfNeeded() internal {
        // 24h sliding window
        if (block.timestamp >= windowStart + 1 days) {
            windowStart = block.timestamp;
            allocatedToday = 0;
            deallocatedToday = 0;
            emit WindowReset(block.timestamp);
        }
    }

    /// @notice View-only suggestion for the next action.
    /// Returns (action, amount):
    ///   action ∈ {"ALLOCATE","DEALLOCATE","OK"}
    function recommendation() public view returns (bytes32 action, uint256 amount) {
        uint256 vaultUsdc = IERC20(usdc).balanceOf(vault); // 6d
        uint256 target = _targetUsdc();

        uint256 upper = (target * (10_000 + upperBps)) / 10_000;
        uint256 lower = (target * (10_000 - lowerBps)) / 10_000;

        if (vaultUsdc > upper) {
            uint256 excess = vaultUsdc - upper;
            action = "ALLOCATE";
            amount = excess;
        } else if (vaultUsdc < lower) {
            uint256 deficit = lower - vaultUsdc;
            action = "DEALLOCATE";
            amount = deficit;
        } else {
            action = "OK";
            amount = 0;
        }
    }

    /// @notice For when THIS policy contract is the Vault owner.
    /// It executes one bounded step toward the target using allocate() or redeem().
    function executeRebalance() external onlyOwner {
        _resetWindowIfNeeded();
        (bytes32 act, uint256 amt) = recommendation();

        if (act == "ALLOCATE" && amt > 0) {
            uint256 step = amt;
            if (step > maxAllocPerTx) step = maxAllocPerTx;
            uint256 capLeft = dailyAllocCap > allocatedToday ? (dailyAllocCap - allocatedToday) : 0;
            if (step > capLeft) step = capLeft;
            if (step > 0) {
                IVaultLike(vault).allocate(step);
                allocatedToday += step;
                emit Executed(act, step);
            }
        } else if (act == "DEALLOCATE" && amt > 0) {
            // redeem takes EUSD (18d); convert USDC amount (6d) 1:1
            uint256 stepUsdc = amt;
            if (stepUsdc > maxDeallocPerTx) stepUsdc = maxDeallocPerTx;
            uint256 capLeft = dailyDeallocCap > deallocatedToday ? (dailyDeallocCap - deallocatedToday) : 0;
            if (stepUsdc > capLeft) stepUsdc = capLeft;

            if (stepUsdc > 0) {
                uint256 stepEusd = stepUsdc * 1e12; // convert 6d→18d
                IVaultLike(vault).redeem(stepEusd);
                deallocatedToday += stepUsdc;
                emit Executed(act, stepUsdc);
            }
        } else {
            emit Executed("OK", 0);
        }
    }
}
