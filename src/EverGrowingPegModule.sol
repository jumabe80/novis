 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

interface IVaultLike {
    function totalBackingUSDC() external view returns (uint256);
}

contract EverGrowingPegModule is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant BPS_DENOMINATOR = 10_000;

    IERC20 public immutable usdc;      // 6 decimals
    IERC20 public immutable fortUSD;   // 18 decimals
    IVaultLike public immutable vault;

    uint16 public premium5PctBps  = 100;
    uint16 public premium10PctBps = 200;
    uint16 public premium15PctBps = 300;
    uint16 public premium20PctBps = 500;

    uint16 public constant BUFFER_5PCT_BPS  = 500;
    uint16 public constant BUFFER_10PCT_BPS = 1_000;
    uint16 public constant BUFFER_15PCT_BPS = 1_500;
    uint16 public constant BUFFER_20PCT_BPS = 2_000;

    uint16 public maxRedeemBufferPctBps = 100; // 1%

    event PremiumRedeemed(address indexed user, uint256 fortUSDAmount, uint256 usdcOut, uint16 premiumBps);

    constructor(address _vault, address _policy, address _usdc, address _fortUSD) Ownable(_policy) {
        vault = IVaultLike(_vault);
        usdc = IERC20(_usdc);
        fortUSD = IERC20(_fortUSD);
    }

    function backingBps() public view returns (uint256) {
        uint256 backingUSDC = vault.totalBackingUSDC();
        uint256 supplyFort = fortUSD.totalSupply();
        if (supplyFort == 0) return 0;
        uint256 theoreticalUSDC = supplyFort / 1e12;
        if (theoreticalUSDC == 0) return 0;
        return (backingUSDC * BPS_DENOMINATOR) / theoreticalUSDC;
    }

    function bufferBps() public view returns (uint256) {
        uint256 bps = backingBps();
        if (bps <= BPS_DENOMINATOR) return 0;
        return bps - BPS_DENOMINATOR;
    }

    function redeemPremium(uint256 amountFortUSD) external nonReentrant {
        require(amountFortUSD > 0, "EGP: amount=0");

        uint256 _bufferBps = bufferBps();
        require(_bufferBps >= BUFFER_5PCT_BPS, "EGP: buffer too low");

        uint16 premiumBps = _calculatePremiumBps(_bufferBps);

        uint256 baseUSDC = amountFortUSD / 1e12;
        require(baseUSDC > 0, "EGP: too small");

        uint256 usdcOut = (baseUSDC * (BPS_DENOMINATOR + premiumBps)) / BPS_DENOMINATOR;

        uint256 backingUSDC = vault.totalBackingUSDC();
        uint256 theoreticalUSDC = fortUSD.totalSupply() / 1e12;
        uint256 bufferUSDC = backingUSDC > theoreticalUSDC ? backingUSDC - theoreticalUSDC : 0;

        uint256 maxOut = (bufferUSDC * maxRedeemBufferPctBps) / BPS_DENOMINATOR;
        require(usdcOut <= maxOut, "EGP: exceeds per-tx buffer");

        require(usdc.balanceOf(address(this)) >= usdcOut, "EGP: insufficient USDC");

        fortUSD.safeTransferFrom(msg.sender, address(this), amountFortUSD);
        usdc.safeTransfer(msg.sender, usdcOut);

        emit PremiumRedeemed(msg.sender, amountFortUSD, usdcOut, premiumBps);
    }

    function previewPremiumRedemption(uint256 amountFortUSD) external view returns (uint256 usdcOut, uint16 premiumBps) {
        if (amountFortUSD == 0) return (0, 0);
        uint256 _bufferBps = bufferBps();
        if (_bufferBps < BUFFER_5PCT_BPS) return (0, 0);
        premiumBps = _calculatePremiumBps(_bufferBps);
        uint256 baseUSDC = amountFortUSD / 1e12;
        if (baseUSDC == 0) return (0, 0);
        usdcOut = (baseUSDC * (BPS_DENOMINATOR + premiumBps)) / BPS_DENOMINATOR;
    }

    function _calculatePremiumBps(uint256 _bufferBps) internal view returns (uint16) {
        if (_bufferBps >= BUFFER_20PCT_BPS) return premium20PctBps;
        if (_bufferBps >= BUFFER_15PCT_BPS) return premium15PctBps;
        if (_bufferBps >= BUFFER_10PCT_BPS) return premium10PctBps;
        return premium5PctBps;
    }

    function setPremiumTiersBps(uint16 _5, uint16 _10, uint16 _15, uint16 _20) external onlyOwner {
        premium5PctBps = _5; premium10PctBps = _10; premium15PctBps = _15; premium20PctBps = _20;
    }

    function setMaxRedeemBufferPctBps(uint16 pctBps) external onlyOwner {
        require(pctBps > 0 && pctBps <= BPS_DENOMINATOR, "EGP: bad pct");
        maxRedeemBufferPctBps = pctBps;
    }
}
