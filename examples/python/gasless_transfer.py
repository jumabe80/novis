"""
NOVIS SDK Example - Gasless Transfer (Python)

This example demonstrates how to send NOVIS without needing ETH for gas.

Usage:
    PRIVATE_KEY=0x... python gasless_transfer.py
"""

import os
import sys

# Add SDK to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'sdk', 'python'))

from novis_sdk import NOVISClient


def main():
    # Check for private key
    private_key = os.environ.get('PRIVATE_KEY')
    if not private_key:
        print('Please set PRIVATE_KEY environment variable')
        sys.exit(1)

    # Initialize client
    client = NOVISClient(private_key)
    print(f'Wallet: {client.address}')

    # Check balance
    balance = client.get_balance()
    print(f'NOVIS Balance: {balance}')

    if float(balance) < 1:
        print('Insufficient NOVIS balance. Need at least 1 NOVIS.')
        sys.exit(1)

    # Recipient address (change this!)
    recipient = '0x9503c0681b4f7bFDc8C39cC1954A458009987Cb9'
    amount = '0.5'  # 0.5 NOVIS

    # Calculate fee first
    print('\n--- Fee Preview ---')
    fee_info = client.calculate_fee(recipient, amount)
    print(f'Amount: {fee_info.amount} NOVIS')
    print(f'Fee: {fee_info.fee} NOVIS ({fee_info.fee_percent})')
    print(f'Recipient gets: {fee_info.net_amount} NOVIS')

    # Execute gasless transfer
    print('\n--- Executing Gasless Transfer ---')
    print('Signing and relaying...')

    try:
        result = client.transfer(recipient, amount)

        print('\n✅ Transfer Successful!')
        print(f'Tx Hash: {result.tx_hash}')
        print(f'Block: {result.block_number}')
        print(f'View: {result.explorer_url}')

        # Check new balance
        new_balance = client.get_balance()
        print(f'\nNew NOVIS Balance: {new_balance}')

    except Exception as e:
        print(f'\n❌ Transfer Failed: {str(e)}')
        sys.exit(1)


if __name__ == '__main__':
    main()
