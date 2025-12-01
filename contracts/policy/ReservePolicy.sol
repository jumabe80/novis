// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IStrategy {
    function totalAssets() external view returns (uint256); // USDC 6d
}

interface IVaultOwner {
    function owner() external view returns (address);
    function transferOwnership(address) external;
}

contract ReservePolicy {
    IERC20 public immutable usdc; // underlying (6 decimals)
    IStrategy public immutable strategy; // strategy holding assets
    address public immutable vault; // your VaultV2

    // basis points (10000 = 100%)
    uint16 public targetBps; // e.g., 2500 = 25%
    uint16 public floorBps; // e.g., 2000 = 20%
    uint16 public ceilBps; // e.g., 3500 = 35%

    // caps (in USDC units, 6 decimals)
    uint256 public maxPerTxAllocate; // push cap per tx
    uint256 public maxPerTxDeallocate; // pull cap per tx
    uint256 public dailyCapAllocate; // per-day push limit
    uint256 public dailyCapDeallocate; // per-day pull limit

    // daily counters
    uint256 public dayIndex; // floor(block.timestamp / 1 days)
    uint256 public usedAllocate; // used for the current day
    uint256 public usedDeallocate;

    address public owner;

    event ParamsUpdated(
        uint16 target,
        uint16 floor,
        uint16 ceil,
        uint256 maxAlloc,
        uint256 maxDealloc,
        uint256 capAlloc,
        uint256 capDealloc
    );
    event Rebalanced(uint256 moveAmount, bool toStrategy);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(
        address _vault,
        address _usdc,
        address _strategy,
        uint16 _targetBps,
        uint16 _floorBps,
        uint16 _ceilBps,
        uint256 _maxPerTxAllocate,
        uint256 _maxPerTxDeallocate,
        uint256 _dailyCapAllocate,
        uint256 _dailyCapDeallocate
    ) {
        require(_vault != address(0) && _usdc != address(0) && _strategy != address(0), "zero addr");
        require(_floorBps <= _targetBps && _targetBps <= _ceilBps, "bad band");

        vault = _vault;
        usdc = IERC20(_usdc);
        strategy = IStrategy(_strategy);

        targetBps = _targetBps;
        floorBps = _floorBps;
        ceilBps = _ceilBps;

        maxPerTxAllocate = _maxPerTxAllocate;
        maxPerTxDeallocate = _maxPerTxDeallocate;
        dailyCapAllocate = _dailyCapAllocate;
        dailyCapDeallocate = _dailyCapDeallocate;

        owner = msg.sender;
        emit OwnerUpdated(address(0), msg.sender);
        emit ParamsUpdated(
            _targetBps,
            _floorBps,
            _ceilBps,
            _maxPerTxAllocate,
            _maxPerTxDeallocate,
            _dailyCapAllocate,
            _dailyCapDeallocate
        );
    }

    // ----- views -----
    function vaultUSDC() public view returns (uint256) {
        return usdc.balanceOf(vault);
    }

    function totalBacking() public view returns (uint256) {
        return vaultUSDC() + strategy.totalAssets();
    }

    function reserveBps() public view returns (uint16) {
        uint256 backing = totalBacking();
        if (backing == 0) return 0;
        uint256 bps = vaultUSDC() * 10000 / backing;
        return uint16(bps);
    }

    function reserveInfo()
        external
        view
        returns (uint16 reservePctBps, uint256 vaultBal, uint256 stratBal, uint16 target, uint16 floor, uint16 ceil)
    {
        vaultBal = vaultUSDC();
        stratBal = strategy.totalAssets();
        reservePctBps = reserveBps();
        target = targetBps;
        floor = floorBps;
        ceil = ceilBps;
    }

    // ----- admin -----
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero");
        emit OwnerUpdated(owner, newOwner);
        owner = newOwner;
    }

    function setParams(
        uint16 _targetBps,
        uint16 _floorBps,
        uint16 _ceilBps,
        uint256 _maxPerTxAllocate,
        uint256 _maxPerTxDeallocate,
        uint256 _dailyCapAllocate,
        uint256 _dailyCapDeallocate
    ) external onlyOwner {
        require(_floorBps <= _targetBps && _targetBps <= _ceilBps, "bad band");

        targetBps = _targetBps;
        floorBps = _floorBps;
        ceilBps = _ceilBps;
        maxPerTxAllocate = _maxPerTxAllocate;
        maxPerTxDeallocate = _maxPerTxDeallocate;
        dailyCapAllocate = _dailyCapAllocate;
        dailyCapDeallocate = _dailyCapDeallocate;

        emit ParamsUpdated(
            _targetBps,
            _floorBps,
            _ceilBps,
            _maxPerTxAllocate,
            _maxPerTxDeallocate,
            _dailyCapAllocate,
            _dailyCapDeallocate
        );
    }

    // ----- caps bookkeeping -----
    function _rollDay() internal {
        uint256 d = block.timestamp / 1 days;
        if (d != dayIndex) {
            dayIndex = d;
            usedAllocate = 0;
            usedDeallocate = 0;
        }
    }

    // ----- core: rebalance to target within caps -----
    function rebalance() external onlyOwner {
        _rollDay();

        (uint256 vBal, uint256 sBal) = (vaultUSDC(), strategy.totalAssets());
        uint256 backing = vBal + sBal;
        if (backing == 0) return;

        uint256 targetVault = (backing * targetBps) / 10000;
        if (vBal < targetVault) {
            // need to pull from strategy
            uint256 need = targetVault - vBal;
            uint256 amt = _capDeallocate(need);
            if (amt > 0) {
                _deallocate(amt);
                emit Rebalanced(amt, false);
            }
        } else if (vBal > targetVault) {
            // need to push to strategy
            uint256 excess = vBal - targetVault;
            uint256 amt = _capAllocate(excess);
            if (amt > 0) {
                _allocate(amt);
                emit Rebalanced(amt, true);
            }
        }
    }

    // manual nudges (still capped)
    function allocate(uint256 amount) external onlyOwner {
        _rollDay();
        _allocate(_capAllocate(amount));
    }

    function deallocate(uint256 amount) external onlyOwner {
        _rollDay();
        _deallocate(_capDeallocate(amount));
    }

    // ----- internal movers with best-effort function discovery -----
    function _allocate(uint256 amount) internal {
        if (amount == 0) return;
        // try: allocate(uint256)
        (bool ok,) = vault.call(abi.encodeWithSignature("allocate(uint256)", amount));
        require(ok, "allocate() failed");
    }

    function _deallocate(uint256 amount) internal {
        if (amount == 0) return;
        // try a few common function names for pull
        (bool ok1,) = vault.call(abi.encodeWithSignature("deallocate(uint256)", amount));
        if (ok1) return;
        (bool ok2,) = vault.call(abi.encodeWithSignature("withdrawFromStrategy(uint256)", amount));
        if (ok2) return;
        (bool ok3,) = vault.call(abi.encodeWithSignature("pull(uint256)", amount));
        require(ok3, "no deallocate fn");
    }

    function _capAllocate(uint256 want) internal returns (uint256 amt) {
        amt = want;
        if (amt > maxPerTxAllocate) amt = maxPerTxAllocate;
        uint256 remaining = (usedAllocate >= dailyCapAllocate) ? 0 : (dailyCapAllocate - usedAllocate);
        if (amt > remaining) amt = remaining;
        usedAllocate += amt;
    }

    function _capDeallocate(uint256 want) internal returns (uint256 amt) {
        amt = want;
        if (amt > maxPerTxDeallocate) amt = maxPerTxDeallocate;
        uint256 remaining = (usedDeallocate >= dailyCapDeallocate) ? 0 : (dailyCapDeallocate - usedDeallocate);
        if (amt > remaining) amt = remaining;
        usedDeallocate += amt;
    }
}
