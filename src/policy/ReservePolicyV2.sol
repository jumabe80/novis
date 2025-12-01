// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// -------- Minimal interfaces (no external imports) --------
interface IERC20 {
    function totalSupply() external view returns (uint256);
}

interface IVaultV2 {
    function owner() external view returns (address);
    function paused() external view returns (bool);
    function totalBackingUSDC() external view returns (uint256);
    function vaultUSDC() external view returns (uint256);
    function totalSupply() external view returns (uint256); // if your Vault doesn't expose this, switch to IERC20(eusd).totalSupply()
    function allocate(uint256 amountUSDC) external; // owner-only
    function withdrawFromStrategy(uint256 amountUSDC) external; // owner-only (rename here if your function name differs)
}

interface IERC20Mini { function totalSupply() external view returns (uint256); }
contract ReservePolicyV2 {
    // ---- Immutable wiring ----
    IVaultV2 public immutable vault;
    address public immutable eusd;
    address public immutable usdc;
    address public immutable strategy; // informational

    // ---- Admin ----
    address public owner;
    address public guardian;

    // ---- Targets & buffers ----
    uint256 public targetBps = 2500; // 25%
    uint256 public upperBps = 200; // +2%
    uint256 public lowerBps = 200; // -2%

    // ---- Per-tx caps (USDC, 6d) ----
    uint256 public maxAllocatePerTx = 50_000e6;
    uint256 public maxDeallocatePerTx = 50_000e6;

    // ---- Daily caps (USDC, 6d) ----
    uint256 public dailyAllocateCap = 200_000e6;
    uint256 public dailyDeallocateCap = 200_000e6;

    // rolling 24h counters
    uint256 public allocatedToday;
    uint256 public deallocatedToday;
    uint256 public lastReset;

    // ---- Pausing ----
    bool public paused;

    // ---- Events ----
    event OwnerSet(address indexed owner);
    event GuardianSet(address indexed guardian);
    event ParamsSet(uint256 targetBps, uint256 upperBps, uint256 lowerBps);
    event TxCapsSet(uint256 maxAllocatePerTx, uint256 maxDeallocatePerTx);
    event DailyCapsSet(uint256 dailyAllocateCap, uint256 dailyDeallocateCap);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event Rebalanced(int256 deviationUSDC, uint256 actionUSDC, bool allocated);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyGuardianOrOwner() {
        require(msg.sender == owner || msg.sender == guardian, "not guardian/owner");
        _;
    }

    constructor(address _vault, address _eusd, address _usdc, address _strategy) {
        require(_vault != address(0) && _eusd != address(0) && _usdc != address(0), "zero addr");
        vault = IVaultV2(_vault);
        eusd = _eusd;
        usdc = _usdc;
        strategy = _strategy;
        owner = msg.sender;
        lastReset = block.timestamp;
        emit OwnerSet(owner);
    }

    // -------- Views --------


    function supplyEusd() public view returns (uint256) {
        return IERC20Mini(eusd).totalSupply();
    }

    function targetUsdc() public view returns (uint256) {
        uint256 supply18 = supplyEusd(); // EUSD has 18d
        uint256 supply6 = supply18 / 1e12; // convert to 6d
        return (supply6 * targetBps) / 10_000; // in USDC units (6d)
    }

    function bandUpperUsdc() public view returns (uint256) {
        return (targetUsdc() * (10_000 + upperBps)) / 10_000;
    }

    function bandLowerUsdc() public view returns (uint256) {
        return (targetUsdc() * (10_000 - lowerBps)) / 10_000;
    }

    function deviationUsdc() public view returns (int256) {
        uint256 v = vault.vaultUSDC();
        uint256 tgt = targetUsdc();
        return int256(v) - int256(tgt); // + => excess in vault; - => shortage in vault
    }

    function capsLeft() public view returns (uint256 allocLeft, uint256 deallocLeft) {
        (uint256 a, uint256 d) = _previewReset(allocatedToday, deallocatedToday, lastReset);
        allocLeft = a >= dailyAllocateCap ? 0 : (dailyAllocateCap - a);
        deallocLeft = d >= dailyDeallocateCap ? 0 : (dailyDeallocateCap - d);
    }

    // -------- Admin --------

    function setOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "zero");
        owner = _owner;
        emit OwnerSet(_owner);
    }

    function setGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
        emit GuardianSet(_guardian);
    }

    function setParams(uint256 _targetBps, uint256 _upperBps, uint256 _lowerBps) external onlyOwner {
        require(_targetBps <= 10_000, "bad target");
        require(_upperBps <= 2000 && _lowerBps <= 2000, "buffers too high");
        targetBps = _targetBps;
        upperBps = _upperBps;
        lowerBps = _lowerBps;
        emit ParamsSet(_targetBps, _upperBps, _lowerBps);
    }

    function setTxCaps(uint256 _maxAllocPerTx, uint256 _maxDeallocPerTx) external onlyOwner {
        maxAllocatePerTx = _maxAllocPerTx;
        maxDeallocatePerTx = _maxDeallocPerTx;
        emit TxCapsSet(_maxAllocPerTx, _maxDeallocPerTx);
    }

    function setDailyCaps(uint256 _allocCap, uint256 _deallocCap) external onlyOwner {
        dailyAllocateCap = _allocCap;
        dailyDeallocateCap = _deallocCap;
        emit DailyCapsSet(_allocCap, _deallocCap);
    }

    function pause() external onlyGuardianOrOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // -------- Core: rebalance --------
    function rebalance() external {
        require(!paused, "paused");
        _maybeReset();

        uint256 v = vault.vaultUSDC();
        uint256 lo = bandLowerUsdc();
        uint256 up = bandUpperUsdc();

        if (v > up) {
            uint256 excess = v - up;
            uint256 amount = _min3(excess, maxAllocatePerTx, _allocLeft());
            if (amount > 0) {
                vault.allocate(amount);
                allocatedToday += amount;
                emit Rebalanced(int256(int256(v) - int256(targetUsdc())), amount, true);
            } else {
                emit Rebalanced(int256(int256(v) - int256(targetUsdc())), 0, true);
            }
            return;
        }

        if (v < lo) {
            uint256 needed = lo - v;
            uint256 amount = _min3(needed, maxDeallocatePerTx, _deallocLeft());
            if (amount > 0) {
                vault.withdrawFromStrategy(amount); // rename if your Vault uses a different selector
                deallocatedToday += amount;
                emit Rebalanced(int256(int256(v) - int256(targetUsdc())), amount, false);
            } else {
                emit Rebalanced(int256(int256(v) - int256(targetUsdc())), 0, false);
            }
            return;
        }

        // within band: no-op
        emit Rebalanced(int256(int256(v) - int256(targetUsdc())), 0, true);
    }

    // -------- Internals --------

    function _maybeReset() internal {
        (allocatedToday, deallocatedToday, lastReset) =
            _computeReset(allocatedToday, deallocatedToday, lastReset, block.timestamp);
    }

    function _previewReset(uint256 a, uint256 d, uint256 last) internal view returns (uint256, uint256) {
        (uint256 na, uint256 nd,) = _computeReset(a, d, last, block.timestamp);
        return (na, nd);
    }

    function _computeReset(uint256 a, uint256 d, uint256 last, uint256 nowTs)
        internal
        pure
        returns (uint256, uint256, uint256)
    {
        if (nowTs > last + 1 days) return (0, 0, nowTs);
        return (a, d, last);
    }

    function _allocLeft() internal view returns (uint256) {
        if (allocatedToday >= dailyAllocateCap) return 0;
        return (dailyAllocateCap - allocatedToday);
    }

    function _deallocLeft() internal view returns (uint256) {
        if (deallocatedToday >= dailyDeallocateCap) return 0;
        return (dailyDeallocateCap - deallocatedToday);
    }

    function _min3(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        uint256 m = a < b ? a : b;
        return m < c ? m : c;
    }
}
