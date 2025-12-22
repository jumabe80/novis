"""
NOVIS SDK

Gasless payments for AI agents on Base.

Example:
    from novis import NOVISClient
    
    client = NOVISClient(private_key=os.environ['PRIVATE_KEY'])
    client.transfer('0x...', 100)
"""

from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_typed_data
import time

# Contract addresses (Base Mainnet)
ADDRESSES = {
    'NOVIS_TOKEN': '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85',
    'VAULT': '0xA3D771bF986174D9cf9C85072cCD11cb72A694d4',
    'PAYMENT_ROUTER': '0xc95D114A333d0394e562BD398c4787fd22d27110',
    'GENESIS': '0xa23a81b1F7fB96DF6d12a579c2660b1ffbAAB2b7',
    'SMART_ACCOUNTS': '0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA',
    'USDC': '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
}

# Network config
NETWORK = {
    'chain_id': 8453,
    'name': 'Base',
    'rpc_url': 'https://mainnet.base.org'
}

# ABIs
TOKEN_ABI = [
    {"name": "balanceOf", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "account", "type": "address"}],
     "outputs": [{"type": "uint256"}]},
    {"name": "transfer", "type": "function",
     "inputs": [{"name": "to", "type": "address"}, {"name": "amount", "type": "uint256"}],
     "outputs": [{"type": "bool"}]},
    {"name": "approve", "type": "function",
     "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}],
     "outputs": [{"type": "bool"}]},
    {"name": "allowance", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
     "outputs": [{"type": "uint256"}]},
    {"name": "nonces", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "owner", "type": "address"}],
     "outputs": [{"type": "uint256"}]},
    {"name": "metaTransferV2", "type": "function",
     "inputs": [
         {"name": "from", "type": "address"},
         {"name": "to", "type": "address"},
         {"name": "amount", "type": "uint256"},
         {"name": "nonce", "type": "uint256"},
         {"name": "deadline", "type": "uint256"},
         {"name": "signature", "type": "bytes"}
     ],
     "outputs": [{"type": "bool"}]}
]

ROUTER_ABI = [
    {"name": "payWithMemo", "type": "function",
     "inputs": [
         {"name": "to", "type": "address"},
         {"name": "amount", "type": "uint256"},
         {"name": "memo", "type": "string"}
     ]},
    {"name": "createEscrow", "type": "function",
     "inputs": [
         {"name": "to", "type": "address"},
         {"name": "amount", "type": "uint256"},
         {"name": "timeout", "type": "uint256"}
     ],
     "outputs": [{"name": "escrowId", "type": "uint256"}]},
    {"name": "releaseEscrow", "type": "function",
     "inputs": [{"name": "escrowId", "type": "uint256"}]},
    {"name": "refundEscrow", "type": "function",
     "inputs": [{"name": "escrowId", "type": "uint256"}]},
    {"name": "getEscrow", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "escrowId", "type": "uint256"}],
     "outputs": [
         {"name": "payer", "type": "address"},
         {"name": "payee", "type": "address"},
         {"name": "amount", "type": "uint256"},
         {"name": "deadline", "type": "uint256"},
         {"name": "released", "type": "bool"},
         {"name": "refunded", "type": "bool"}
     ]},
    {"name": "batchPay", "type": "function",
     "inputs": [
         {"name": "recipients", "type": "address[]"},
         {"name": "amounts", "type": "uint256[]"},
         {"name": "memos", "type": "string[]"}
     ]}
]

VAULT_ABI = [
    {"name": "deposit", "type": "function",
     "inputs": [{"name": "usdcAmount", "type": "uint256"}]},
    {"name": "redeem", "type": "function",
     "inputs": [{"name": "novisAmount", "type": "uint256"}]},
    {"name": "totalBackingUSDC", "type": "function", "stateMutability": "view",
     "inputs": [],
     "outputs": [{"type": "uint256"}]}
]

USDC_ABI = [
    {"name": "balanceOf", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "account", "type": "address"}],
     "outputs": [{"type": "uint256"}]},
    {"name": "approve", "type": "function",
     "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}],
     "outputs": [{"type": "bool"}]},
    {"name": "allowance", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
     "outputs": [{"type": "uint256"}]}
]


class NOVISClient:
    """
    NOVIS Client for gasless payments on Base.
    
    Args:
        private_key: Wallet private key
        rpc_url: Custom RPC URL (optional)
    
    Example:
        client = NOVISClient(private_key='0x...')
        client.transfer('0xRecipient...', 100)
    """
    
    def __init__(self, private_key: str, rpc_url: str = NETWORK['rpc_url']):
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        self.account = Account.from_key(private_key)
        self.chain_id = NETWORK['chain_id']
        
        # Contract instances
        self.token = self.w3.eth.contract(
            address=ADDRESSES['NOVIS_TOKEN'], abi=TOKEN_ABI
        )
        self.router = self.w3.eth.contract(
            address=ADDRESSES['PAYMENT_ROUTER'], abi=ROUTER_ABI
        )
        self.vault = self.w3.eth.contract(
            address=ADDRESSES['VAULT'], abi=VAULT_ABI
        )
        self.usdc = self.w3.eth.contract(
            address=ADDRESSES['USDC'], abi=USDC_ABI
        )
    
    @property
    def address(self) -> str:
        """Get wallet address."""
        return self.account.address
    
    # ============================================
    # BALANCE & INFO
    # ============================================
    
    def get_balance(self, address: str = None) -> float:
        """Get NOVIS balance."""
        addr = address or self.address
        balance = self.token.functions.balanceOf(addr).call()
        return float(self.w3.from_wei(balance, 'ether'))
    
    def get_usdc_balance(self, address: str = None) -> float:
        """Get USDC balance."""
        addr = address or self.address
        balance = self.usdc.functions.balanceOf(addr).call()
        return float(balance) / 1e6
    
    def get_total_backing(self) -> float:
        """Get total USDC backing in vault."""
        backing = self.vault.functions.totalBackingUSDC().call()
        return float(backing) / 1e6
    
    # ============================================
    # TRANSFERS
    # ============================================
    
    def transfer(self, to: str, amount: float) -> dict:
        """
        Transfer NOVIS tokens.
        
        Args:
            to: Recipient address
            amount: Amount in NOVIS
            
        Returns:
            Transaction receipt
        """
        amount_wei = self.w3.to_wei(amount, 'ether')
        tx = self._build_tx(
            self.token.functions.transfer(to, amount_wei)
        )
        return self._send_tx(tx)
    
    def pay_with_memo(self, to: str, amount: float, memo: str) -> dict:
        """
        Pay with memo (attach reference to payment).
        
        Args:
            to: Recipient address
            amount: Amount in NOVIS
            memo: Payment reference/memo
            
        Returns:
            Transaction receipt
        """
        self._ensure_router_allowance(amount)
        amount_wei = self.w3.to_wei(amount, 'ether')
        tx = self._build_tx(
            self.router.functions.payWithMemo(to, amount_wei, memo)
        )
        return self._send_tx(tx)
    
    def batch_pay(self, payments: list) -> dict:
        """
        Batch pay multiple recipients.
        
        Args:
            payments: List of {'to': address, 'amount': float, 'memo': str}
            
        Returns:
            Transaction receipt
        """
        total = sum(p['amount'] for p in payments)
        self._ensure_router_allowance(total)
        
        recipients = [p['to'] for p in payments]
        amounts = [self.w3.to_wei(p['amount'], 'ether') for p in payments]
        memos = [p.get('memo', '') for p in payments]
        
        tx = self._build_tx(
            self.router.functions.batchPay(recipients, amounts, memos)
        )
        return self._send_tx(tx)
    
    # ============================================
    # ESCROW
    # ============================================
    
    def create_escrow(self, to: str, amount: float, timeout: int = 3600) -> dict:
        """
        Create escrow payment.
        
        Args:
            to: Payee address
            amount: Amount in NOVIS
            timeout: Timeout in seconds (default: 1 hour)
            
        Returns:
            Transaction receipt
        """
        self._ensure_router_allowance(amount)
        amount_wei = self.w3.to_wei(amount, 'ether')
        tx = self._build_tx(
            self.router.functions.createEscrow(to, amount_wei, timeout)
        )
        return self._send_tx(tx)
    
    def release_escrow(self, escrow_id: int) -> dict:
        """Release escrow (send funds to payee)."""
        tx = self._build_tx(
            self.router.functions.releaseEscrow(escrow_id)
        )
        return self._send_tx(tx)
    
    def refund_escrow(self, escrow_id: int) -> dict:
        """Refund escrow (return funds to payer)."""
        tx = self._build_tx(
            self.router.functions.refundEscrow(escrow_id)
        )
        return self._send_tx(tx)
    
    def get_escrow(self, escrow_id: int) -> dict:
        """Get escrow details."""
        result = self.router.functions.getEscrow(escrow_id).call()
        return {
            'payer': result[0],
            'payee': result[1],
            'amount': float(self.w3.from_wei(result[2], 'ether')),
            'deadline': result[3],
            'released': result[4],
            'refunded': result[5]
        }
    
    # ============================================
    # MINT / REDEEM
    # ============================================
    
    def mint(self, usdc_amount: float) -> dict:
        """
        Mint NOVIS by depositing USDC.
        
        Args:
            usdc_amount: Amount of USDC to deposit
            
        Returns:
            Transaction receipt
        """
        amount_wei = int(usdc_amount * 1e6)
        
        # Approve USDC
        allowance = self.usdc.functions.allowance(
            self.address, ADDRESSES['VAULT']
        ).call()
        
        if allowance < amount_wei:
            approve_tx = self._build_tx(
                self.usdc.functions.approve(ADDRESSES['VAULT'], 2**256 - 1)
            )
            self._send_tx(approve_tx)
        
        tx = self._build_tx(
            self.vault.functions.deposit(amount_wei)
        )
        return self._send_tx(tx)
    
    def redeem(self, novis_amount: float) -> dict:
        """
        Redeem NOVIS for USDC.
        
        Args:
            novis_amount: Amount of NOVIS to redeem
            
        Returns:
            Transaction receipt
        """
        amount_wei = self.w3.to_wei(novis_amount, 'ether')
        tx = self._build_tx(
            self.vault.functions.redeem(amount_wei)
        )
        return self._send_tx(tx)
    
    # ============================================
    # HELPERS
    # ============================================
    
    def _ensure_router_allowance(self, amount: float):
        """Ensure router has sufficient allowance."""
        amount_wei = self.w3.to_wei(amount, 'ether')
        allowance = self.token.functions.allowance(
            self.address, ADDRESSES['PAYMENT_ROUTER']
        ).call()
        
        if allowance < amount_wei:
            approve_tx = self._build_tx(
                self.token.functions.approve(ADDRESSES['PAYMENT_ROUTER'], 2**256 - 1)
            )
            self._send_tx(approve_tx)
    
    def _build_tx(self, func):
        """Build transaction dict."""
        return func.build_transaction({
            'from': self.address,
            'nonce': self.w3.eth.get_transaction_count(self.address),
            'gas': 300000,
            'gasPrice': self.w3.eth.gas_price,
            'chainId': self.chain_id
        })
    
    def _send_tx(self, tx: dict) -> dict:
        """Sign and send transaction."""
        signed = self.account.sign_transaction(tx)
        tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        return {
            'tx_hash': tx_hash.hex(),
            'block_number': receipt.blockNumber,
            'gas_used': receipt.gasUsed,
            'status': receipt.status
        }


__all__ = ['NOVISClient', 'ADDRESSES', 'NETWORK']
