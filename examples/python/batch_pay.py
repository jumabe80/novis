"""
NOVIS Batch Payment Example (Python)

Pay multiple recipients in a single transaction.

Usage:
    PRIVATE_KEY=0x... python batch_pay.py
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
    {"name": "approve", "type": "function",
     "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}],
     "outputs": [{"type": "bool"}]},
    {"name": "allowance", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "owner", "type": "address"}, {"name": "spender", "type": "address"}],
     "outputs": [{"type": "uint256"}]},
    {"name": "balanceOf", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "account", "type": "address"}],
     "outputs": [{"type": "uint256"}]}
]

ROUTER_ABI = [
    {"name": "batchPay", "type": "function",
     "inputs": [
         {"name": "recipients", "type": "address[]"},
         {"name": "amounts", "type": "uint256[]"},
         {"name": "memos", "type": "string[]"}
     ]}
]


def main():
    private_key = os.environ.get('PRIVATE_KEY')
    if not private_key:
        print('Error: PRIVATE_KEY environment variable required')
        sys.exit(1)

    # Setup
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = Account.from_key(private_key)
    token = w3.eth.contract(address=NOVIS_TOKEN, abi=TOKEN_ABI)
    router = w3.eth.contract(address=PAYMENT_ROUTER, abi=ROUTER_ABI)

    print('=' * 50)
    print('NOVIS Batch Payment')
    print('=' * 50)
    print(f'Wallet: {account.address}')

    # Check balance
    balance = token.functions.balanceOf(account.address).call()
    balance_formatted = float(w3.from_wei(balance, 'ether'))
    print(f'Balance: {balance_formatted} NOVIS')

    # Example payments (replace with your own)
    payments = [
        {
            'to': '0x1111111111111111111111111111111111111111',
            'amount': 1.0,
            'memo': 'task:research_topic_001'
        },
        {
            'to': '0x2222222222222222222222222222222222222222',
            'amount': 2.0,
            'memo': 'task:write_summary_002'
        },
        {
            'to': '0x3333333333333333333333333333333333333333',
            'amount': 1.5,
            'memo': 'task:review_content_003'
        }
    ]

    # Calculate total
    total = sum(p['amount'] for p in payments)
    print(f'\nPayments to send:')
    for i, p in enumerate(payments):
        print(f"  {i + 1}. {p['to'][:10]}... → {p['amount']} NOVIS ({p['memo']})")
    print(f'  Total: {total} NOVIS')

    # Check if we have enough
    if balance_formatted < total:
        print('\nError: Insufficient balance')
        sys.exit(1)

    # Approve router
    allowance = token.functions.allowance(account.address, PAYMENT_ROUTER).call()
    total_wei = w3.to_wei(total, 'ether')

    if allowance < total_wei:
        print('\nApproving router...')
        nonce = w3.eth.get_transaction_count(account.address)
        approve_tx = token.functions.approve(
            PAYMENT_ROUTER,
            2**256 - 1
        ).build_transaction({
            'from': account.address,
            'nonce': nonce,
            'gas': 100000,
            'gasPrice': w3.eth.gas_price,
            'chainId': CHAIN_ID
        })
        signed = account.sign_transaction(approve_tx)
        tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
        w3.eth.wait_for_transaction_receipt(tx_hash)
        print('Approved!')

    # Execute batch payment
    print('\nSending batch payment...')

    recipients = [p['to'] for p in payments]
    amounts = [w3.to_wei(p['amount'], 'ether') for p in payments]
    memos = [p['memo'] for p in payments]

    nonce = w3.eth.get_transaction_count(account.address)
    tx = router.functions.batchPay(
        recipients,
        amounts,
        memos
    ).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 500000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })

    signed = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f'TX Hash: {tx_hash.hex()}')

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f'\n✅ Batch payment successful!')
    print(f'Block: {receipt.blockNumber}')
    print(f'Gas used: {receipt.gasUsed}')

    # Check new balance
    new_balance = token.functions.balanceOf(account.address).call()
    print(f'\nNew balance: {w3.from_wei(new_balance, "ether")} NOVIS')


if __name__ == '__main__':
    main()
