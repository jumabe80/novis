// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IComet {
    function supply(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract StrategyCometV3Upgradeable is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuard, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public usdc;
    IComet public comet;
    address public vault;

    uint256[50] private __gap;

    event Deposited(address indexed from, uint256 assets, uint256 shares);
    event Withdrawn(address indexed to, uint256 shares, uint256 assets);
    event VaultSet(address indexed vault);
    event CometSet(address indexed comet);
    event TokensRescued(address indexed token, uint256 amount);
    event ETHRescued(uint256 amount);
    event EmergencyWithdraw(uint256 amount);

    modifier onlyVault() { require(msg.sender == vault, "only vault"); _; }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address _owner, address _vault, address _usdc, address _comet) public initializer {
        __ERC20_init("NOVIS Strategy Comet", "nsNVS");
        __Ownable_init(_owner);
        
        require(_vault != address(0) && _usdc != address(0) && _comet != address(0), "zero");
        vault = _vault;
        usdc = IERC20(_usdc);
        comet = IComet(_comet);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function deposit(uint256 amount, address onBehalfOf) external onlyVault nonReentrant returns (uint256 shares) {
        require(amount > 0, "zero");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdc.approve(address(comet), amount);
        comet.supply(address(usdc), amount);
        shares = amount;
        _mint(onBehalfOf, shares);
        emit Deposited(onBehalfOf, amount, shares);
    }

    function withdraw(uint256 shares, address to) external onlyVault nonReentrant returns (uint256 assets) {
        require(shares > 0 && balanceOf(msg.sender) >= shares, "invalid");
        _burn(msg.sender, shares);
        assets = shares;
        comet.withdraw(address(usdc), assets);
        usdc.safeTransfer(to, assets);
        emit Withdrawn(to, shares, assets);
    }

    function asset() external view returns (address) { return address(usdc); }
    function totalAssets() external view returns (uint256) { return comet.balanceOf(address(this)); }

    function setVault(address _vault) external onlyOwner { require(_vault != address(0), "zero"); vault = _vault; emit VaultSet(_vault); }
    function setComet(address _comet) external onlyOwner { require(_comet != address(0), "zero"); comet = IComet(_comet); emit CometSet(_comet); }

    function rescueToken(address token, uint256 amount) external onlyOwner {
        require(token != address(usdc), "use emergencyWithdraw");
        IERC20(token).safeTransfer(owner(), amount);
        emit TokensRescued(token, amount);
    }
    function rescueETH(uint256 amount) external onlyOwner { (bool s, ) = owner().call{value: amount}(""); require(s, "failed"); emit ETHRescued(amount); }
    function emergencyWithdraw() external onlyOwner nonReentrant {
        uint256 bal = comet.balanceOf(address(this));
        if (bal > 0) { comet.withdraw(address(usdc), bal); usdc.safeTransfer(owner(), usdc.balanceOf(address(this))); emit EmergencyWithdraw(bal); }
    }
    function version() external pure returns (string memory) { return "1.0.0"; }
    receive() external payable {}
}
