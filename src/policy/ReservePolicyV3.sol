// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 { function approve(address,uint256) external returns (bool); }

contract ReservePolicyV3 {
    // Core wiring (all swapable post-deploy)
    address public owner;
    address public guardian;

    address public vault;
    address public eusd;
    address public usdc;
    address public strategy;

    // Params / caps (same as V2 naming so callers stay coherent)
    uint256 public targetBps; // 0..10_000
    uint256 public upperBps;
    uint256 public lowerBps;
    uint256 public maxAllocPerTx;
    uint256 public maxDeallocPerTx;
    uint256 public dailyAllocCap;
    uint256 public dailyDeallocCap;

    event OwnerSet(address indexed newOwner);
    event GuardianSet(address indexed newGuardian);
    event WiringUpdated(address vault,address eusd,address usdc,address strategy);
    event ParamsSet(uint256 target,uint256 upper,uint256 lower);
    event TxCapsSet(uint256 maxAlloc,uint256 maxDealloc);
    event DailyCapsSet(uint256 allocCap,uint256 deallocCap);

    modifier onlyOwner() { require(msg.sender == owner, "not owner"); _; }

    constructor(address _owner, address _vault, address _eusd, address _usdc, address _strategy) {
        owner = _owner;
        vault = _vault;
        eusd = _eusd;
        usdc = _usdc;
        strategy = _strategy;
        emit OwnerSet(_owner);
        emit WiringUpdated(_vault,_eusd,_usdc,_strategy);
    }

    // --- Ownership / admin ---
    function setOwner(address _owner) external onlyOwner { owner = _owner; emit OwnerSet(_owner); }
    function setGuardian(address _guardian) external onlyOwner { guardian = _guardian; emit GuardianSet(_guardian); }

    // --- Wiring (swapable) ---
    function setVault(address _vault) external onlyOwner { vault = _vault; emit WiringUpdated(vault,eusd,usdc,strategy); }
    function setEusd(address _eusd) external onlyOwner { eusd = _eusd; emit WiringUpdated(vault,eusd,usdc,strategy); }
    function setUsdc(address _usdc) external onlyOwner { usdc = _usdc; emit WiringUpdated(vault,eusd,usdc,strategy); }
    function setStrategy(address _strategy) external onlyOwner { strategy = _strategy; emit WiringUpdated(vault,eusd,usdc,strategy); }

    // --- Params / caps (same API names as V2) ---
    function setParams(uint256 _targetBps, uint256 _upperBps, uint256 _lowerBps) external onlyOwner {
        targetBps = _targetBps; upperBps = _upperBps; lowerBps = _lowerBps;
        emit ParamsSet(_targetBps,_upperBps,_lowerBps);
    }
    function setTxCaps(uint256 _maxAllocPerTx, uint256 _maxDeallocPerTx) external onlyOwner {
        maxAllocPerTx = _maxAllocPerTx; maxDeallocPerTx = _maxDeallocPerTx;
        emit TxCapsSet(_maxAllocPerTx,_maxDeallocPerTx);
    }
    function setDailyCaps(uint256 _allocCap, uint256 _deallocCap) external onlyOwner {
        dailyAllocCap = _allocCap; dailyDeallocCap = _deallocCap;
        emit DailyCapsSet(_allocCap,_deallocCap);
    }

    // --- Generic exec so we can mint/burn on owned contracts, approve tokens, etc. ---
    function exec(address target, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory) {
        (bool ok, bytes memory ret) = target.call{value:value}(data);
        require(ok, "exec revert");
        return ret;
    }
}
