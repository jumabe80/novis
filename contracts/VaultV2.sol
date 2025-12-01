// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Minimal EUSD interface (your EUSD has mint/burn)
interface IEUSD is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}

// Your IStrategy interface (you already created it in contracts/interfaces/IStrategy.sol)
// interface IStrategy { function asset() external view returns (address); function totalAssets() external view returns (uint256); function deposit(uint256 amount, address onBehalfOf) external returns (uint256); function withdraw(uint256 shares, address to) external returns (uint256); }
import {IStrategy} from "./interfaces/IStrategy.sol";

contract VaultV2 is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IEUSD;

    IERC20 public immutable usdc; // 6 decimals
    IEUSD public immutable eusd; // 18 decimals

    IStrategy public strategy; // optional strategy

    uint256 private constant SCALE = 1e12; // 6d -> 18d

    event StrategySet(address indexed strategy);
    event Allocated(uint256 amountUSDC, uint256 sharesReceived);
    event Deallocated(uint256 sharesBurned, uint256 assetsReceived);

    constructor(address _usdc, address _eusd, address initialOwner) Ownable(initialOwner) {
        _transferOwnership(initialOwner);

        require(_usdc != address(0) && _eusd != address(0), "bad addr");
        usdc = IERC20(_usdc);
        eusd = IEUSD(_eusd);
    }

    // ----- core mint/redeem -----
    function deposit(uint256 amountUSDC) external whenNotPaused nonReentrant {
        require(amountUSDC > 0, "amount=0");
        usdc.safeTransferFrom(msg.sender, address(this), amountUSDC);
        eusd.mint(msg.sender, amountUSDC * SCALE);
    }

    function redeem(uint256 amountEUSD) external whenNotPaused nonReentrant {
        require(amountEUSD > 0, "amount=0");
        // pull EUSD then burn from this vault
        eusd.safeTransferFrom(msg.sender, address(this), amountEUSD);
        eusd.burn(amountEUSD);
        // send USDC back
        uint256 amt = amountEUSD / SCALE;
        usdc.safeTransfer(msg.sender, amt);
    }

    // ----- owner controls -----
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setStrategy(address s) external onlyOwner {
        if (s == address(0)) {
            strategy = IStrategy(address(0));
            emit StrategySet(address(0));
            return;
        }
        require(IStrategy(s).asset() == address(usdc), "bad asset");
        strategy = IStrategy(s);
        emit StrategySet(s);
    }

    // move idle USDC to strategy, shares owned by this vault
    function allocate(uint256 amountUSDC) external onlyOwner nonReentrant {
        require(address(strategy) != address(0), "no strategy");
        require(amountUSDC > 0, "amount=0");
        IERC20(usdc).approve(address(strategy), amountUSDC);
        uint256 shares = strategy.deposit(amountUSDC, address(this));
        emit Allocated(amountUSDC, shares);
    }

    // pull USDC back by burning 'shares' from vault balance
    function deallocate(uint256 shares) external onlyOwner nonReentrant {
        require(address(strategy) != address(0), "no strategy");
        require(shares > 0, "shares=0");
        uint256 assets = strategy.withdraw(shares, address(this));
        emit Deallocated(shares, assets);
    }

    // views for UI
    function vaultUSDC() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function strategyShares() public view returns (uint256) {
        if (address(strategy) == address(0)) return 0;
        return ERC20(address(strategy)).balanceOf(address(this));
    }

    function totalBackingUSDC() external view returns (uint256) {
        uint256 onVault = vaultUSDC();
        uint256 onStrat = 0;
        if (address(strategy) != address(0)) {
            onStrat = strategy.totalAssets();
        }
        return onVault + onStrat;
    }
}
