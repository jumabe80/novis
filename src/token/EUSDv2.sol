// Minimal EUSD v2 (mint/burn/owner) for mint/redeem on testnet
pragma solidity ^0.8.18;

contract EUSDv2 {
    string public constant name = "EVO Dollar v2";
    string public constant symbol = "EUSD";
    uint8  public constant decimals = 18;

    address public owner;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event OwnerSet(address indexed owner);

    constructor(address _owner){ owner = _owner; emit OwnerSet(_owner); }
    modifier onlyOwner(){ require(msg.sender==owner, "not owner"); _; }
    function setOwner(address o) external onlyOwner { owner = o; emit OwnerSet(o); }

    function mint(address to, uint256 amt) external onlyOwner {
        totalSupply += amt; balanceOf[to] += amt; emit Transfer(address(0), to, amt);
    }
    function burn(uint256 amt) external {
        uint256 bal = balanceOf[msg.sender]; require(bal>=amt, "bal");
        balanceOf[msg.sender]=bal-amt; totalSupply-=amt; emit Transfer(msg.sender,address(0),amt);
    }
    function transfer(address to, uint256 amt) external returns(bool){
        uint256 bal = balanceOf[msg.sender]; require(bal>=amt,"bal");
        balanceOf[msg.sender]=bal-amt; balanceOf[to]+=amt; emit Transfer(msg.sender,to,amt); return true;
    }
}
