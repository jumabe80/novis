"""
NOVIS SDK for Python

Gasless transactions for humans and AI agents on Base.

Version: 1.0.0
License: MIT
"""

import json
import time
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from decimal import Decimal

import requests
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_typed_data

# =============================================================================
# CONSTANTS
# =============================================================================

ADDRESSES = {
    "NOVIS_TOKEN": "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85",
    "VAULT": "0xA3D771bF986174D9cf9C85072cCD11cb72A694d4",
    "STRATEGY": "0x064E4586b7C63777BDC98A4776D3f78A93C0B752",
    "FACTORY": "0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA",
    "DEX_POOL": "0xA0af1C990433102EFb08D78E060Ab05E6874ca69",
    "TREASURY": "0x4709280aef7A496EA84e72dB3CAbAd5e324d593e",
    "USDC": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "ENTRYPOINT": "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    "RELAYER_API": "https://novis-relayer-production.up.railway.app",
    "RPC_URL": "https://mainnet.base.org",
    "CHAIN_ID": 8453
}

NOVIS_ABI = [
    {"name": "name", "type": "function", "inputs": [], "outputs": [{"type": "string"}], "stateMutability": "view"},
    {"name": "symbol", "type": "function", "inputs": [], "outputs": [{"type": "string"}], "stateMutability": "view"},
    {"name": "decimals", "type": "function", "inputs": [], "outputs": [{"type": "uint8"}], "stateMutability": "view"},
    {"name": "totalSupply", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "balanceOf", "type": "function", "inputs": [{"name": "account", "type": "address"}], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "transfer", "type": "function", "inputs": [{"name": "to", "type": "address"}, {"name": "amount", "type": "uint256"}], "outputs": [{"type": "bool"}], "stateMutability": "nonpayable"},
    {"name": "feeThreshold", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "feePercentageBps", "type": "function", "inputs": [], "outputs": [{"type": "uint16"}], "stateMutability": "view"},
    {"name": "totalFeesCollected", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "totalMetaTxRelayed", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "calculateTransferFee", "type": "function", "inputs": [{"name": "from", "type": "address"}, {"name": "to", "type": "address"}, {"name": "amount", "type": "uint256"}], "outputs": [{"type": "uint256"}, {"type": "uint256"}], "stateMutability": "view"},
]

VAULT_ABI = [
    {"name": "deposit", "type": "function", "inputs": [{"name": "amount", "type": "uint256"}], "outputs": [{"type": "uint256"}], "stateMutability": "nonpayable"},
    {"name": "redeem", "type": "function", "inputs": [{"name": "amount", "type": "uint256"}], "outputs": [{"type": "uint256"}], "stateMutability": "nonpayable"},
    {"name": "totalAssets", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "backingRatioBps", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
]

FACTORY_ABI = [
    {"name": "createAccount", "type": "function", "inputs": [{"name": "owner", "type": "address"}, {"name": "dailyLimit", "type": "uint256"}, {"name": "salt", "type": "bytes32"}], "outputs": [{"type": "address"}], "stateMutability": "nonpayable"},
    {"name": "accountCount", "type": "function", "inputs": [], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "accounts", "type": "function", "inputs": [{"name": "index", "type": "uint256"}], "outputs": [{"type": "address"}], "stateMutability": "view"},
    {"name": "getAccountsByOwner", "type": "function", "inputs": [{"name": "owner", "type": "address"}], "outputs": [{"type": "address[]"}], "stateMutability": "view"},
]

USDC_ABI = [
    {"name": "balanceOf", "type": "function", "inputs": [{"name": "account", "type": "address"}], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
    {"name": "approve", "type": "function", "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}], "outputs": [{"type": "bool"}], "stateMutability": "nonpayable"},
    {"name": "allowance", "type": "function", "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}], "outputs": [{"type": "uint256"}], "stateMutability": "view"},
]


# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class TransferResult:
    success: bool
    tx_hash: str
    block_number: int
    from_address: str
    to_address: str
    amount: str
    explorer_url: str


@dataclass
class FeeInfo:
    amount: str
    amount_wei: str
    fee: str
    fee_wei: str
    net_amount: str
    net_amount_wei: str
    fee_percent: str


@dataclass
class ProtocolStats:
    total_supply: str
    total_assets: str
    backing_ratio_bps: int
    backing_ratio_percent: str
    total_fees_collected: str
    total_meta_tx_relayed: int
    fee_threshold: str
    fee_percentage: str


# =============================================================================
# NOVIS CLIENT
# =============================================================================

class NOVISClient:
    """
    NOVIS SDK Client for Python
    
    Example:
        client = NOVISClient(private_key="0x...")
        result = client.transfer("0xRecipient...", "10.0")
        print(result.tx_hash)
    """
    
    def __init__(
        self,
        private_key: str,
        rpc_url: str = None,
        relayer_url: str = None
    ):
        """
        Initialize NOVIS client
        
        Args:
            private_key: Wallet private key (with or without 0x prefix)
            rpc_url: Optional custom RPC URL
            relayer_url: Optional custom relayer URL
        """
        self.rpc_url = rpc_url or ADDRESSES["RPC_URL"]
        self.relayer_url = relayer_url or ADDRESSES["RELAYER_API"]
        
        self.w3 = Web3(Web3.HTTPProvider(self.rpc_url))
        self.account = Account.from_key(private_key)
        
        self.novis = self.w3.eth.contract(
            address=Web3.to_checksum_address(ADDRESSES["NOVIS_TOKEN"]),
            abi=NOVIS_ABI
        )
        self.vault = self.w3.eth.contract(
            address=Web3.to_checksum_address(ADDRESSES["VAULT"]),
            abi=VAULT_ABI
        )
        self.factory = self.w3.eth.contract(
            address=Web3.to_checksum_address(ADDRESSES["FACTORY"]),
            abi=FACTORY_ABI
        )
        self.usdc = self.w3.eth.contract(
            address=Web3.to_checksum_address(ADDRESSES["USDC"]),
            abi=USDC_ABI
        )
    
    @property
    def address(self) -> str:
        """Get wallet address"""
        return self.account.address
    
    # =========================================================================
    # BALANCE & INFO
    # =========================================================================
    
    def get_balance(self, address: str = None) -> str:
        """
        Get NOVIS balance
        
        Args:
            address: Address to check (defaults to wallet)
            
        Returns:
            Balance in NOVIS (human readable)
        """
        addr = Web3.to_checksum_address(address or self.address)
        balance = self.novis.functions.balanceOf(addr).call()
        return str(Web3.from_wei(balance, 'ether'))
    
    def get_usdc_balance(self, address: str = None) -> str:
        """Get USDC balance (6 decimals)"""
        addr = Web3.to_checksum_address(address or self.address)
        balance = self.usdc.functions.balanceOf(addr).call()
        return str(Decimal(balance) / Decimal(10**6))
    
    def get_eth_balance(self, address: str = None) -> str:
        """Get ETH balance"""
        addr = Web3.to_checksum_address(address or self.address)
        balance = self.w3.eth.get_balance(addr)
        return str(Web3.from_wei(balance, 'ether'))
    
    def get_protocol_stats(self) -> ProtocolStats:
        """Get protocol statistics"""
        total_supply = self.novis.functions.totalSupply().call()
        total_assets = self.vault.functions.totalAssets().call()
        backing_ratio = self.vault.functions.backingRatioBps().call()
        total_fees = self.novis.functions.totalFeesCollected().call()
        total_meta_tx = self.novis.functions.totalMetaTxRelayed().call()
        fee_threshold = self.novis.functions.feeThreshold().call()
        fee_bps = self.novis.functions.feePercentageBps().call()
        
        return ProtocolStats(
            total_supply=str(Web3.from_wei(total_supply, 'ether')),
            total_assets=str(Decimal(total_assets) / Decimal(10**6)),
            backing_ratio_bps=backing_ratio,
            backing_ratio_percent=f"{backing_ratio / 100:.2f}%",
            total_fees_collected=str(Web3.from_wei(total_fees, 'ether')),
            total_meta_tx_relayed=total_meta_tx,
            fee_threshold=str(Web3.from_wei(fee_threshold, 'ether')),
            fee_percentage=f"{fee_bps / 100:.2f}%"
        )
    
    # =========================================================================
    # GASLESS TRANSFER
    # =========================================================================
    
    def transfer(self, to: str, amount: str) -> TransferResult:
        """
        Send NOVIS gaslessly via meta-transaction
        
        Args:
            to: Recipient address
            amount: Amount in NOVIS (e.g., "10.0")
            
        Returns:
            TransferResult with transaction details
        """
        to = Web3.to_checksum_address(to)
        amount_wei = Web3.to_wei(Decimal(amount), 'ether')
        
        # 1. Get nonce
        nonce_res = requests.get(f"{self.relayer_url}/nonce/{self.address}")
        nonce_res.raise_for_status()
        nonce = int(nonce_res.json()["nonce"])
        
        # 2. Get domain
        domain_res = requests.get(f"{self.relayer_url}/domain")
        domain_res.raise_for_status()
        domain_data = domain_res.json()
        
        # 3. Build EIP-712 typed data
        deadline = int(time.time()) + 3600  # 1 hour
        
        typed_data = {
            "types": {
                "EIP712Domain": [
                    {"name": "name", "type": "string"},
                    {"name": "version", "type": "string"},
                    {"name": "chainId", "type": "uint256"},
                    {"name": "verifyingContract", "type": "address"}
                ],
                "MetaTransfer": [
                    {"name": "from", "type": "address"},
                    {"name": "to", "type": "address"},
                    {"name": "amount", "type": "uint256"},
                    {"name": "nonce", "type": "uint256"},
                    {"name": "deadline", "type": "uint256"}
                ]
            },
            "primaryType": "MetaTransfer",
            "domain": {
                "name": domain_data["name"],
                "version": domain_data["version"],
                "chainId": int(domain_data["chainId"]),
                "verifyingContract": domain_data["verifyingContract"]
            },
            "message": {
                "from": self.address,
                "to": to,
                "amount": amount_wei,
                "nonce": nonce,
                "deadline": deadline
            }
        }
        
        # 4. Sign
        encoded = encode_typed_data(full_message=typed_data)
        signed = self.account.sign_message(encoded)
        signature = signed.signature.hex()
        
        # 5. Relay
        relay_res = requests.post(
            f"{self.relayer_url}/relay",
            json={
                "from": self.address,
                "to": to,
                "amount": str(amount_wei),
                "deadline": str(deadline),
                "signature": signature
            }
        )
        result = relay_res.json()
        
        if not result.get("success"):
            raise Exception(result.get("error", "Relay failed"))
        
        return TransferResult(
            success=True,
            tx_hash=result["txHash"],
            block_number=result["blockNumber"],
            from_address=self.address,
            to_address=to,
            amount=amount,
            explorer_url=f"https://basescan.org/tx/{result['txHash']}"
        )
    
    def calculate_fee(self, to: str, amount: str) -> FeeInfo:
        """Calculate fee for a transfer"""
        to = Web3.to_checksum_address(to)
        amount_wei = Web3.to_wei(Decimal(amount), 'ether')
        
        fee, net = self.novis.functions.calculateTransferFee(
            self.address, to, amount_wei
        ).call()
        
        return FeeInfo(
            amount=amount,
            amount_wei=str(amount_wei),
            fee=str(Web3.from_wei(fee, 'ether')),
            fee_wei=str(fee),
            net_amount=str(Web3.from_wei(net, 'ether')),
            net_amount_wei=str(net),
            fee_percent="0.1%" if fee > 0 else "0%"
        )
    
    # =========================================================================
    # DIRECT TRANSFER
    # =========================================================================
    
    def transfer_direct(self, to: str, amount: str) -> Dict[str, Any]:
        """
        Send NOVIS directly (requires ETH for gas)
        
        Args:
            to: Recipient address
            amount: Amount in NOVIS
            
        Returns:
            Transaction result dict
        """
        to = Web3.to_checksum_address(to)
        amount_wei = Web3.to_wei(Decimal(amount), 'ether')
        
        tx = self.novis.functions.transfer(to, amount_wei).build_transaction({
            'from': self.address,
            'nonce': self.w3.eth.get_transaction_count(self.address),
            'gas': 100000,
            'gasPrice': self.w3.eth.gas_price
        })
        
        signed = self.account.sign_transaction(tx)
        tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        
        return {
            "success": receipt.status == 1,
            "tx_hash": tx_hash.hex(),
            "block_number": receipt.blockNumber,
            "gas_used": receipt.gasUsed,
            "explorer_url": f"https://basescan.org/tx/{tx_hash.hex()}"
        }
    
    # =========================================================================
    # SMART ACCOUNTS
    # =========================================================================
    
    def create_smart_account(self, daily_limit: str) -> str:
        """
        Create a smart account for AI agent
        
        Args:
            daily_limit: Daily spending limit in NOVIS
            
        Returns:
            Smart account address
        """
        daily_limit_wei = Web3.to_wei(Decimal(daily_limit), 'ether')
        salt = Web3.keccak(text=str(time.time()))
        
        tx = self.factory.functions.createAccount(
            self.address,
            daily_limit_wei,
            salt
        ).build_transaction({
            'from': self.address,
            'nonce': self.w3.eth.get_transaction_count(self.address),
            'gas': 500000,
            'gasPrice': self.w3.eth.gas_price
        })
        
        signed = self.account.sign_transaction(tx)
        tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
        self.w3.eth.wait_for_transaction_receipt(tx_hash)
        
        # Get account address
        count = self.factory.functions.accountCount().call()
        account_address = self.factory.functions.accounts(count - 1).call()
        
        return account_address
    
    def get_my_smart_accounts(self) -> List[str]:
        """Get all smart accounts owned by this wallet"""
        return self.factory.functions.getAccountsByOwner(self.address).call()


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def format_novis(wei: int) -> str:
    """Format wei to NOVIS"""
    return str(Web3.from_wei(wei, 'ether'))

def parse_novis(amount: str) -> int:
    """Parse NOVIS string to wei"""
    return Web3.to_wei(Decimal(amount), 'ether')

def format_usdc(wei: int) -> str:
    """Format wei to USDC (6 decimals)"""
    return str(Decimal(wei) / Decimal(10**6))

def parse_usdc(amount: str) -> int:
    """Parse USDC string to wei"""
    return int(Decimal(amount) * Decimal(10**6))

def is_valid_address(address: str) -> bool:
    """Check if address is valid"""
    return Web3.is_address(address)


# =============================================================================
# MAIN (for testing)
# =============================================================================

if __name__ == "__main__":
    import os
    
    pk = os.environ.get("PRIVATE_KEY")
    if not pk:
        print("Set PRIVATE_KEY environment variable")
        exit(1)
    
    client = NOVISClient(pk)
    print(f"Address: {client.address}")
    print(f"NOVIS Balance: {client.get_balance()}")
    print(f"ETH Balance: {client.get_eth_balance()}")
    
    stats = client.get_protocol_stats()
    print(f"\nProtocol Stats:")
    print(f"  Total Supply: {stats.total_supply} NOVIS")
    print(f"  Backing Ratio: {stats.backing_ratio_percent}")
    print(f"  Total Fees: {stats.total_fees_collected} NOVIS")
    print(f"  Meta-Txs: {stats.total_meta_tx_relayed}")
