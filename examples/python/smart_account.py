"""
NOVIS Smart Account Example (Python)

Create and manage AI agent smart accounts with spending limits.

Usage:
    PRIVATE_KEY=0x... python smart_account.py create <daily_limit>
    PRIVATE_KEY=0x... python smart_account.py fund <account_address> <amount>
    python smart_account.py info <account_address>
"""

import os
import sys
from web3 import Web3
from eth_account import Account

# Config
NOVIS_TOKEN = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85'
SMART_ACCOUNT_FACTORY = '0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA'
RPC_URL = 'https://mainnet.base.org'
CHAIN_ID = 8453

# ABIs
TOKEN_ABI = [
    {"name": "transfer", "type": "function",
     "inputs": [{"name": "to", "type": "address"}, {"name": "amount", "type": "uint256"}],
     "outputs": [{"type": "bool"}]},
    {"name": "balanceOf", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "account", "type": "address"}],
     "outputs": [{"type": "uint256"}]}
]

FACTORY_ABI = [
    {"name": "createAccount", "type": "function",
     "inputs": [
         {"name": "owner", "type": "address"},
         {"name": "dailyLimit", "type": "uint256"}
     ],
     "outputs": [{"name": "", "type": "address"}]},
    {"name": "getAccount", "type": "function", "stateMutability": "view",
     "inputs": [{"name": "owner", "type": "address"}],
     "outputs": [{"name": "", "type": "address"}]}
]

SMART_ACCOUNT_ABI = [
    {"name": "owner", "type": "function", "stateMutability": "view",
     "inputs": [],
     "outputs": [{"type": "address"}]},
    {"name": "dailyLimit", "type": "function", "stateMutability": "view",
     "inputs": [],
     "outputs": [{"type": "uint256"}]},
    {"name": "spentToday", "type": "function", "stateMutability": "view",
     "inputs": [],
     "outputs": [{"type": "uint256"}]},
    {"name": "lastSpendDate", "type": "function", "stateMutability": "view",
     "inputs": [],
     "outputs": [{"type": "uint256"}]}
]


def get_web3():
    return Web3(Web3.HTTPProvider(RPC_URL))


def get_account():
    private_key = os.environ.get('PRIVATE_KEY')
    if not private_key:
        print('Error: PRIVATE_KEY environment variable required')
        sys.exit(1)
    return Account.from_key(private_key)


def create_smart_account(daily_limit: str):
    w3 = get_web3()
    account = get_account()
    factory = w3.eth.contract(address=SMART_ACCOUNT_FACTORY, abi=FACTORY_ABI)

    print('Creating smart account...')
    print(f'  Owner: {account.address}')
    print(f'  Daily Limit: {daily_limit} NOVIS')

    limit_wei = w3.to_wei(float(daily_limit), 'ether')

    nonce = w3.eth.get_transaction_count(account.address)
    tx = factory.functions.createAccount(
        account.address,
        limit_wei
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

    # Get account address
    smart_account_address = factory.functions.getAccount(account.address).call()

    print(f'\n✅ Smart Account created!')
    print(f'   Address: {smart_account_address}')
    print(f'\nNext steps:')
    print(f'  1. Fund it: python smart_account.py fund {smart_account_address} 100')
    print(f'  2. Use it for AI agent transactions')


def fund_smart_account(account_address: str, amount: str):
    w3 = get_web3()
    account = get_account()
    token = w3.eth.contract(address=NOVIS_TOKEN, abi=TOKEN_ABI)

    print('Funding smart account...')
    print(f'  Account: {account_address}')
    print(f'  Amount: {amount} NOVIS')

    amount_wei = w3.to_wei(float(amount), 'ether')

    nonce = w3.eth.get_transaction_count(account.address)
    tx = token.functions.transfer(
        account_address,
        amount_wei
    ).build_transaction({
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
    print(f'\n✅ Funded successfully!')

    # Check new balance
    balance = token.functions.balanceOf(account_address).call()
    print(f'Account balance: {w3.from_wei(balance, "ether")} NOVIS')


def get_account_info(account_address: str):
    w3 = get_web3()
    token = w3.eth.contract(address=NOVIS_TOKEN, abi=TOKEN_ABI)
    smart_account = w3.eth.contract(address=account_address, abi=SMART_ACCOUNT_ABI)

    print('Smart Account Info')
    print('=' * 50)
    print(f'Address: {account_address}')

    try:
        owner = smart_account.functions.owner().call()
        daily_limit = smart_account.functions.dailyLimit().call()
        spent_today = smart_account.functions.spentToday().call()
        balance = token.functions.balanceOf(account_address).call()

        print(f'Owner: {owner}')
        print(f'Balance: {w3.from_wei(balance, "ether")} NOVIS')
        print(f'Daily Limit: {w3.from_wei(daily_limit, "ether")} NOVIS')
        print(f'Spent Today: {w3.from_wei(spent_today, "ether")} NOVIS')
        print(f'Remaining: {w3.from_wei(daily_limit - spent_today, "ether")} NOVIS')
    except Exception as e:
        print(f'\n⚠️ Could not read account info. Is this a valid smart account?')
        print(f'   Error: {e}')


def main():
    if len(sys.argv) < 2:
        print('NOVIS Smart Account Manager')
        print('=' * 50)
        print('Usage:')
        print('  python smart_account.py create <daily_limit>')
        print('  python smart_account.py fund <account_address> <amount>')
        print('  python smart_account.py info <account_address>')
        print('')
        print('Examples:')
        print('  python smart_account.py create 100        # Create with 100 NOVIS/day limit')
        print('  python smart_account.py fund 0x... 50     # Fund with 50 NOVIS')
        print('  python smart_account.py info 0x...        # Get account info')
        sys.exit(1)

    command = sys.argv[1]

    if command == 'create':
        daily_limit = sys.argv[2] if len(sys.argv) > 2 else '100'
        create_smart_account(daily_limit)

    elif command == 'fund':
        if len(sys.argv) < 4:
            print('Error: account_address and amount required')
            sys.exit(1)
        fund_smart_account(sys.argv[2], sys.argv[3])

    elif command == 'info':
        if len(sys.argv) < 3:
            print('Error: account_address required')
            sys.exit(1)
        get_account_info(sys.argv[2])

    else:
        print(f'Unknown command: {command}')
        sys.exit(1)


if __name__ == '__main__':
    main()
