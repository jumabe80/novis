"""
NOVIS Escrow Example (Python)

Create and manage escrow payments for AI agent tasks.

Usage:
    PRIVATE_KEY=0x... python escrow.py create <recipient> <amount> <timeout_seconds>
    PRIVATE_KEY=0x... python escrow.py release <escrow_id>
    PRIVATE_KEY=0x... python escrow.py refund <escrow_id>
    python escrow.py status <escrow_id>
"""

import os
import sys
from web3 import Web3
from eth_account import Account

# Config
NOVIS_TOKEN = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85'
PAYMENT_ROUTER = '0xc95D114A333d0394e562BD398c4787fd22d27110'
RPC_URL = 'https://mainnet.base.org'
CHAIN_ID = 8453

# ABIs
TOKEN_ABI = [
    {
        "name": "approve",
        "type": "function",
        "inputs": [
            {"name": "spender", "type": "address"},
            {"name": "amount", "type": "uint256"}
        ],
        "outputs": [{"type": "bool"}]
    },
    {
        "name": "allowance",
        "type": "function",
        "stateMutability": "view",
        "inputs": [
            {"name": "owner", "type": "address"},
            {"name": "spender", "type": "address"}
        ],
        "outputs": [{"type": "uint256"}]
    }
]

ROUTER_ABI = [
    {
        "name": "createEscrow",
        "type": "function",
        "inputs": [
            {"name": "to", "type": "address"},
            {"name": "amount", "type": "uint256"},
            {"name": "timeout", "type": "uint256"}
        ],
        "outputs": [{"name": "escrowId", "type": "uint256"}]
    },
    {
        "name": "releaseEscrow",
        "type": "function",
        "inputs": [{"name": "escrowId", "type": "uint256"}],
        "outputs": []
    },
    {
        "name": "refundEscrow",
        "type": "function",
        "inputs": [{"name": "escrowId", "type": "uint256"}],
        "outputs": []
    },
    {
        "name": "getEscrow",
        "type": "function",
        "stateMutability": "view",
        "inputs": [{"name": "escrowId", "type": "uint256"}],
        "outputs": [
            {"name": "payer", "type": "address"},
            {"name": "payee", "type": "address"},
            {"name": "amount", "type": "uint256"},
            {"name": "deadline", "type": "uint256"},
            {"name": "released", "type": "bool"},
            {"name": "refunded", "type": "bool"}
        ]
    }
]


def get_web3():
    return Web3(Web3.HTTPProvider(RPC_URL))


def get_account():
    private_key = os.environ.get('PRIVATE_KEY')
    if not private_key:
        print('Error: PRIVATE_KEY environment variable required')
        sys.exit(1)
    return Account.from_key(private_key)


def create_escrow(recipient: str, amount: str, timeout: int):
    w3 = get_web3()
    account = get_account()
    
    token = w3.eth.contract(address=NOVIS_TOKEN, abi=TOKEN_ABI)
    router = w3.eth.contract(address=PAYMENT_ROUTER, abi=ROUTER_ABI)
    
    amount_wei = w3.to_wei(float(amount), 'ether')
    
    # Check allowance
    allowance = token.functions.allowance(account.address, PAYMENT_ROUTER).call()
    if allowance < amount_wei:
        print('Approving router to spend NOVIS...')
        nonce = w3.eth.get_transaction_count(account.address)
        tx = token.functions.approve(
            PAYMENT_ROUTER,
            2**256 - 1  # Max approval
        ).build_transaction({
            'from': account.address,
            'nonce': nonce,
            'gas': 100000,
            'gasPrice': w3.eth.gas_price,
            'chainId': CHAIN_ID
        })
        signed = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
        w3.eth.wait_for_transaction_receipt(tx_hash)
        print('Approved!')
    
    # Create escrow
    print(f'\nCreating escrow...')
    print(f'  Recipient: {recipient}')
    print(f'  Amount: {amount} NOVIS')
    print(f'  Timeout: {timeout} seconds')
    
    nonce = w3.eth.get_transaction_count(account.address)
    tx = router.functions.createEscrow(
        recipient,
        amount_wei,
        timeout
    ).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 200000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    
    signed = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f'TX Hash: {tx_hash.hex()}')
    
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f'\n✅ Escrow created! Block: {receipt.blockNumber}')
    print(f'Check logs for escrow ID')


def release_escrow(escrow_id: int):
    w3 = get_web3()
    account = get_account()
    router = w3.eth.contract(address=PAYMENT_ROUTER, abi=ROUTER_ABI)
    
    print(f'Releasing escrow #{escrow_id}...')
    
    nonce = w3.eth.get_transaction_count(account.address)
    tx = router.functions.releaseEscrow(escrow_id).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 100000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    
    signed = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f'TX Hash: {tx_hash.hex()}')
    
    w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f'\n✅ Escrow released! Funds sent to payee.')


def refund_escrow(escrow_id: int):
    w3 = get_web3()
    account = get_account()
    router = w3.eth.contract(address=PAYMENT_ROUTER, abi=ROUTER_ABI)
    
    print(f'Refunding escrow #{escrow_id}...')
    
    nonce = w3.eth.get_transaction_count(account.address)
    tx = router.functions.refundEscrow(escrow_id).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 100000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })
    
    signed = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f'TX Hash: {tx_hash.hex()}')
    
    w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f'\n✅ Escrow refunded! Funds returned to payer.')


def get_escrow_status(escrow_id: int):
    import time
    
    w3 = get_web3()
    router = w3.eth.contract(address=PAYMENT_ROUTER, abi=ROUTER_ABI)
    
    print(f'\nEscrow #{escrow_id} Status:')
    print('=' * 40)
    
    escrow = router.functions.getEscrow(escrow_id).call()
    payer, payee, amount, deadline, released, refunded = escrow
    
    print(f'Payer:    {payer}')
    print(f'Payee:    {payee}')
    print(f'Amount:   {w3.from_wei(amount, "ether")} NOVIS')
    print(f'Deadline: {time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(deadline))} UTC')
    print(f'Released: {released}')
    print(f'Refunded: {refunded}')
    
    now = int(time.time())
    if not released and not refunded:
        if now < deadline:
            remaining = (deadline - now) // 60
            print(f'\nStatus: ⏳ PENDING ({remaining} minutes remaining)')
        else:
            print(f'\nStatus: ⚠️ EXPIRED (can be refunded)')
    elif released:
        print(f'\nStatus: ✅ RELEASED')
    else:
        print(f'\nStatus: ↩️ REFUNDED')


def main():
    if len(sys.argv) < 2:
        print('NOVIS Escrow Manager')
        print('=' * 40)
        print('Usage:')
        print('  python escrow.py create <recipient> <amount> <timeout>')
        print('  python escrow.py release <escrow_id>')
        print('  python escrow.py refund <escrow_id>')
        print('  python escrow.py status <escrow_id>')
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == 'create':
        if len(sys.argv) < 4:
            print('Error: recipient and amount required')
            sys.exit(1)
        recipient = sys.argv[2]
        amount = sys.argv[3]
        timeout = int(sys.argv[4]) if len(sys.argv) > 4 else 3600
        create_escrow(recipient, amount, timeout)
    
    elif command == 'release':
        if len(sys.argv) < 3:
            print('Error: escrow_id required')
            sys.exit(1)
        release_escrow(int(sys.argv[2]))
    
    elif command == 'refund':
        if len(sys.argv) < 3:
            print('Error: escrow_id required')
            sys.exit(1)
        refund_escrow(int(sys.argv[2]))
    
    elif command == 'status':
        if len(sys.argv) < 3:
            print('Error: escrow_id required')
            sys.exit(1)
        get_escrow_status(int(sys.argv[2]))
    
    else:
        print(f'Unknown command: {command}')
        sys.exit(1)


if __name__ == '__main__':
    main()
