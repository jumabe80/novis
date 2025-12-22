# NOVIS Quick Start Guide

Get started with NOVIS in 5 minutes.

---

## Prerequisites

- Node.js 18+ or Python 3.9+
- A wallet with a private key
- Some NOVIS tokens (get from [Aerodrome](https://aerodrome.finance/swap?from=0x833589fcd6edb6e08f4c7c32d4f71b54bda02913&to=0x1fb5e1c0c3dec8da595e531b31c7b30c540e6b85))

---

## Option 1: JavaScript

### Install
```bash
npm install ethers
```

### Send Gasless Transfer
```javascript
import { ethers } from 'ethers';

// Setup
const NOVIS_TOKEN = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85';
const RELAYER_URL = 'https://novisdefi.com/api/relay';
const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// NOVIS Token ABI (only what we need)
const NOVIS_ABI = [
  'function nonces(address owner) view returns (uint256)',
  'function metaTransferV2(address from, address to, uint256 amount, uint256 nonce, uint256 deadline, bytes signature)'
];

const novis = new ethers.Contract(NOVIS_TOKEN, NOVIS_ABI, wallet);

// Create signature for gasless transfer
async function signTransfer(to, amount) {
  const nonce = await novis.nonces(wallet.address);
  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
  
  const domain = {
    name: 'NOVIS',
    version: '1',
    chainId: 8453,
    verifyingContract: NOVIS_TOKEN
  };
  
  const types = {
    MetaTransfer: [
      { name: 'from', type: 'address' },
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' }
    ]
  };
  
  const value = {
    from: wallet.address,
    to: to,
    amount: ethers.parseEther(amount),
    nonce: nonce,
    deadline: deadline
  };
  
  const signature = await wallet.signTypedData(domain, types, value);
  
  return { ...value, signature, deadline };
}

// Send to relayer
async function transfer(to, amount) {
  const signed = await signTransfer(to, amount);
  
  const response = await fetch(RELAYER_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'transfer',
      from: wallet.address,
      to: signed.to,
      amount: signed.amount.toString(),
      nonce: signed.nonce.toString(),
      deadline: signed.deadline,
      signature: signed.signature
    })
  });
  
  return response.json();
}

// Usage
const result = await transfer('0xRecipient...', '100');
console.log('TX Hash:', result.txHash);
```

---

## Option 2: Python

### Install
```bash
pip install web3 eth-account
```

### Send Gasless Transfer
```python
import os
import json
import requests
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_typed_data

# Setup
NOVIS_TOKEN = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85'
RELAYER_URL = 'https://novisdefi.com/api/relay'
RPC_URL = 'https://mainnet.base.org'

w3 = Web3(Web3.HTTPProvider(RPC_URL))
account = Account.from_key(os.environ['PRIVATE_KEY'])

# Minimal ABI
NOVIS_ABI = [
    {
        "inputs": [{"name": "owner", "type": "address"}],
        "name": "nonces",
        "outputs": [{"type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    }
]

novis = w3.eth.contract(address=NOVIS_TOKEN, abi=NOVIS_ABI)

def sign_transfer(to: str, amount: float):
    nonce = novis.functions.nonces(account.address).call()
    deadline = int(time.time()) + 3600
    amount_wei = w3.to_wei(amount, 'ether')
    
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
            "name": "NOVIS",
            "version": "1",
            "chainId": 8453,
            "verifyingContract": NOVIS_TOKEN
        },
        "message": {
            "from": account.address,
            "to": to,
            "amount": amount_wei,
            "nonce": nonce,
            "deadline": deadline
        }
    }
    
    signed = account.sign_typed_data(full_message=typed_data)
    
    return {
        "from": account.address,
        "to": to,
        "amount": str(amount_wei),
        "nonce": str(nonce),
        "deadline": deadline,
        "signature": signed.signature.hex()
    }

def transfer(to: str, amount: float):
    signed = sign_transfer(to, amount)
    
    response = requests.post(RELAYER_URL, json={
        "action": "transfer",
        **signed
    })
    
    return response.json()

# Usage
result = transfer('0xRecipient...', 100)
print(f"TX Hash: {result['txHash']}")
```

---

## Next Steps

- [Payment Router](payment-router.md) — Escrow, memos, batch payments
- [Smart Accounts](smart-accounts.md) — AI agent wallets with limits
- [Examples](../examples/) — More code samples

---

## Need Help?

- Twitter: [@NOVISdefi](https://twitter.com/NOVISdefi)
- GitHub Issues: [github.com/jumabe80/novis/issues](https://github.com/jumabe80/novis/issues)
