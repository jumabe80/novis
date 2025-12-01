// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IEUSD is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}

contract Vault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IEUSD;

    IERC20 public immutable usdc; // 6 decimals
    IEUSD public immutable eusd; // 18 decimals

    uint256 private constant SCALAR = 1e12; // 10^(18-6)

    event Minted(address indexed user, uint256 usdcIn, uint256 eusdOut);
    event Redeemed(address indexed user, uint256 eusdIn, uint256 usdcOut);
    event EmergencyUSDCWithdraw(address indexed to, uint256 amount);

    constructor(address _usdc, address _eusd, address _owner) Ownable(_owner) {
        require(_usdc != address(0) && _eusd != address(0) && _owner != address(0), "zero addr");
        usdc = IERC20(_usdc);
        eusd = IEUSD(_eusd);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Deposit USDC (6d) to receive EUSD (18d) 1:1
    /// @param usdcAmount amount in 6 decimals
    function deposit(uint256 usdcAmount) external nonReentrant whenNotPaused {
        require(usdcAmount > 0, "amount=0");
        // Pull USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Mint EUSD to user (scale 6d -> 18d)
        uint256 eusdAmount = usdcAmount * SCALAR;
        eusd.mint(msg.sender, eusdAmount);

        emit Minted(msg.sender, usdcAmount, eusdAmount);
    }

    /// @notice Redeem EUSD (18d) to receive USDC (6d) 1:1
    /// Requires user to approve EUSD to this Vault.
    function redeem(uint256 eusdAmount) external nonReentrant whenNotPaused {
        require(eusdAmount > 0, "amount=0");

        // Pull EUSD from user to this contract
        eusd.safeTransferFrom(msg.sender, address(this), eusdAmount);

        // Burn EUSD held by the Vault (msg.sender is Vault in burn())
        eusd.burn(eusdAmount);

        // Send USDC back (scale 18d -> 6d)
        uint256 usdcAmount = eusdAmount / SCALAR;
        usdc.safeTransfer(msg.sender, usdcAmount);

        emit Redeemed(msg.sender, eusdAmount, usdcAmount);
    }

    /// @dev Admin function for testnet ops; consider removing/guarding for mainnet.
    function emergencyWithdrawUSDC(address to, uint256 amount) external onlyOwner {
        usdc.safeTransfer(to, amount);
        emit EmergencyUSDCWithdraw(to, amount);
    }
}
