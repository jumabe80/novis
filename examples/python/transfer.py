"""
NOVIS Transfer Example (Python)

Send a NOVIS transfer.

Usage:
    PRIVATE_KEY=0x... python transfer.py <recipient> <amount>

Example:
    PRIVATE_KEY=0x... python transfer.py 0x1234...5678 100
"""

import os
import sys
import time
from web3 import Web3
from eth_account import Account

# Config
NOVIS_TOKEN = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85'
RPC_URL = 'https://mainnet.base.org'
CHAIN_ID = 8453

# ABI (only what we need)
NOVIS_ABI = [
    {
        "name": "balanceOf",
        "type": "function",
        "stateMutability": "view",
        "inputs": [{"name": "account", "type": "address"}],
        "outputs": [{"type": "uint256"}]
    },
    {
        "name": "nonces",
        "type": "function",
        "stateMutability": "view",
        "inputs": [{"name": "owner", "type": "address"}],
        "outputs": [{"type": "uint256"}]
    },
    {
        "name": "transfer",
        "type": "function",
        "inputs": [
            {"name": "to", "type": "address"},
            {"name": "amount", "type": "uint256"}
        ],
        "outputs": [{"type": "bool"}]
    }
]


def main():
    # Parse args
    if len(sys.argv) != 3:
        print('Usage: PRIVATE_KEY=0x... python transfer.py <recipient> <amount>')
        print('Example: PRIVATE_KEY=0x... python transfer.py 0x1234...5678 100')
        sys.exit(1)

    recipient = sys.argv[1]
    amount = sys.argv[2]

    private_key = os.environ.get('PRIVATE_KEY')
    if not private_key:
        print('Error: PRIVATE_KEY environment variable required')
        sys.exit(1)

    # Setup
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    account = Account.from_key(private_key)
    novis = w3.eth.contract(address=NOVIS_TOKEN, abi=NOVIS_ABI)

    print('=' * 50)
    print('NOVIS Transfer')
    print('=' * 50)
    print(f'From:   {account.address}')
    print(f'To:     {recipient}')
    print(f'Amount: {amount} NOVIS')
    print('=' * 50)

    # Check balance
    balance = novis.functions.balanceOf(account.address).call()
    balance_formatted = w3.from_wei(balance, 'ether')
    print(f'Balance: {balance_formatted} NOVIS')

    amount_wei = w3.to_wei(float(amount), 'ether')
    if balance < amount_wei:
        print('Error: Insufficient balance')
        sys.exit(1)

    # Build transaction
    print('\nBuilding transaction...')
    nonce = w3.eth.get_transaction_count(account.address)
    
    tx = novis.functions.transfer(
        recipient,
        amount_wei
    ).build_transaction({
        'from': account.address,
        'nonce': nonce,
        'gas': 100000,
        'gasPrice': w3.eth.gas_price,
        'chainId': CHAIN_ID
    })

    # Sign and send
    print('Signing transaction...')
    signed_tx = account.sign_transaction(tx)

    print('Sending transaction...')
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    print(f'TX Hash: {tx_hash.hex()}')

    print('Waiting for confirmation...')
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    
    print(f'\n✅ Success! Block: {receipt.blockNumber}')
    print(f'Gas used: {receipt.gasUsed}')

    # Check new balance
    new_balance = novis.functions.balanceOf(account.address).call()
    print(f'\nNew balance: {w3.from_wei(new_balance, "ether")} NOVIS')


if __name__ == '__main__':
    main()
