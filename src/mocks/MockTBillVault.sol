pragma solidity ^0.8.18;

interface IERC20 {
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

contract MockTBillVault {
    IERC20 public immutable usdc;
    string public constant name = "Mock T-Bill Vault";
    string public constant symbol = "mTBILL";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    uint256 private _totalAssets;

    constructor(address _usdc) { usdc = IERC20(_usdc); }

    function asset() external view returns (address) { return address(usdc); }
    function totalAssets() public view returns (uint256) { return _totalAssets; }

    function assetsPerShare() public view returns (uint256) {
        return totalSupply == 0 ? 1_000_000 : (_totalAssets * 1_000_000) / totalSupply;
    }

    function deposit(uint256 assets, address to) external returns (uint256 shares) {
        require(usdc.transferFrom(msg.sender, address(this), assets), "transferFrom fail");
        shares = totalSupply == 0 ? assets : (assets * totalSupply) / _totalAssets;
        _totalAssets += assets;
        totalSupply += shares;
        balanceOf[to] += shares;
    }

    function withdraw(uint256 shares, address to) external returns (uint256 assets) {
        require(balanceOf[msg.sender] >= shares, "insufficient");
        assets = (shares * _totalAssets) / totalSupply;
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        _totalAssets -= assets;
        require(usdc.transfer(to, assets), "transfer fail");
    }

    function donate(uint256 assets) external {
        require(usdc.transferFrom(msg.sender, address(this), assets), "transferFrom fail");
        _totalAssets += assets;
    }
}
