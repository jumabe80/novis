// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title StrategyCometV3
 * @notice Yield strategy using Compound V3 (Comet) with full rescue capabilities
 * @dev Only VaultV3 can deposit/withdraw. Owner (SAFE) can rescue and transfer ownership.
 */

interface IComet {
    function supply(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract StrategyCometV3 is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Immutables ============
    IERC20 public immutable usdc;
    IComet public immutable comet;
    address public immutable vault;

    // ============ Events ============
    event Deposited(address indexed from, uint256 assets, uint256 shares);
    event Withdrawn(address indexed to, uint256 shares, uint256 assets);
    event TokensRescued(address indexed token, uint256 amount);
    event ETHRescued(uint256 amount);
    event EmergencyWithdraw(uint256 amount);

    // ============ Modifiers ============
    modifier onlyVault() {
        require(msg.sender == vault, "only vault");
        _;
    }

    // ============ Constructor ============
    constructor(
        address _owner,
        address _vault,
        address _usdc,
        address _comet
    ) ERC20("NOVIS Strategy Comet", "nsNVS") Ownable(_owner) {
        require(_vault != address(0), "vault zero");
        require(_usdc != address(0), "usdc zero");
        require(_comet != address(0), "comet zero");
        
        vault = _vault;
        usdc = IERC20(_usdc);
        comet = IComet(_comet);
    }

    // ============ Vault Functions ============

    /**
     * @notice Deposit USDC into Comet (only VaultV3)
     * @param amount USDC amount to deposit
     * @param onBehalfOf Address to credit shares to
     * @return shares Amount of strategy shares minted
     */
    function deposit(uint256 amount, address onBehalfOf) external onlyVault nonReentrant returns (uint256 shares) {
        require(amount > 0, "amount zero");
        
        // Transfer USDC from vault
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        
        // Supply to Comet
        usdc.approve(address(comet), amount);
        comet.supply(address(usdc), amount);
        
        // Mint shares 1:1
        shares = amount;
        _mint(onBehalfOf, shares);
        
        emit Deposited(onBehalfOf, amount, shares);
    }

    /**
     * @notice Withdraw USDC from Comet (only VaultV3)
     * @param shares Amount of shares to burn
     * @param to Address to send USDC to
     * @return assets Amount of USDC withdrawn
     */
    function withdraw(uint256 shares, address to) external onlyVault nonReentrant returns (uint256 assets) {
        require(shares > 0, "shares zero");
        require(balanceOf(msg.sender) >= shares, "insufficient shares");
        
        // Burn shares
        _burn(msg.sender, shares);
        
        // Withdraw from Comet (shares ≈ assets)
        assets = shares;
        comet.withdraw(address(usdc), assets);
        
        // Transfer USDC to recipient
        usdc.safeTransfer(to, assets);
        
        emit Withdrawn(to, shares, assets);
    }

    // ============ View Functions ============

    /**
     * @notice Asset this strategy manages
     */
    function asset() external view returns (address) {
        return address(usdc);
    }

    /**
     * @notice Total USDC held in Comet
     */
    function totalAssets() external view returns (uint256) {
        return comet.balanceOf(address(this));
    }

    // ============ Rescue Functions (Owner - SAFE) ============

    /**
     * @notice Rescue stuck tokens (not USDC in normal operation)
     * @dev For USDC, use emergencyWithdraw instead
     */
    function rescueToken(address token, uint256 amount) external onlyOwner {
        require(token != address(usdc), "use emergencyWithdraw for USDC");
        IERC20(token).safeTransfer(owner(), amount);
        emit TokensRescued(token, amount);
    }

    /**
     * @notice Rescue stuck ETH
     */
    function rescueETH(uint256 amount) external onlyOwner {
        (bool success, ) = owner().call{value: amount}("");
        require(success, "ETH transfer failed");
        emit ETHRescued(amount);
    }

    /**
     * @notice Emergency withdraw all from Comet to owner
     * @dev Only use in emergency - bypasses vault
     */
    function emergencyWithdraw() external onlyOwner nonReentrant {
        uint256 balance = comet.balanceOf(address(this));
        if (balance > 0) {
            comet.withdraw(address(usdc), balance);
            uint256 usdcBalance = usdc.balanceOf(address(this));
            usdc.safeTransfer(owner(), usdcBalance);
            emit EmergencyWithdraw(usdcBalance);
        }
    }

    // ============ Ownership ============

    // transferOwnership(address newOwner) - inherited from Ownable

    // ============ Receive ETH ============
    receive() external payable {}
}
