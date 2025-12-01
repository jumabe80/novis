// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ERC20 minimal, compatible with VaultV2:
// - transfer/approve/transferFrom present
// - mint(address,uint256) onlyOwner (Vault must be owner so deposit can mint)
// - burn(uint256) burns msg.sender balance (no onlyOwner) so redeem() works after transferFrom
contract EUSDv3Premint {
    string public name = "NOVIS";
    string public symbol = "NVS";
    uint8  public decimals = 18;

    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnerSet(address indexed newOwner);

    modifier onlyOwner() { require(msg.sender == owner, "not owner"); _; }

    constructor(address _owner, address _premintTo, uint256 _premintAmount) {
        owner = _owner;
        emit OwnerSet(_owner);
        if (_premintAmount > 0) _mint(_premintTo, _premintAmount);
    }

    // --- ERC20 ---
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value); return true;
    }
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value; emit Approval(msg.sender, spender, value); return true;
    }
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, value); return true;
    }

    // --- Mint/Burn ---
    function mint(address to, uint256 amount) external onlyOwner { _mint(to, amount); }
    // NOTE: burn burns msg.sender (e.g., the Vault after it received EUSD via transferFrom in redeem)
    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "balance");
        unchecked { balanceOf[msg.sender] -= amount; }
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    // --- Admin ---
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner; emit OwnerSet(newOwner);
    }

    // --- Internals ---
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "to zero");
        require(balanceOf[from] >= value, "balance");
        unchecked { balanceOf[from] -= value; balanceOf[to] += value; }
        emit Transfer(from, to, value);
    }
    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "to zero");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
