# NOVIS Contract Addresses & ABIs

All contracts are deployed on **Base Mainnet** (Chain ID: 8453).

---

## Contract Addresses

| Contract | Address | Verified |
|----------|---------|----------|
| **NOVIS Token** | `0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85` | ✅ [BaseScan](https://basescan.org/address/0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85) |
| **Vault** | `0xA3D771bF986174D9cf9C85072cCD11cb72A694d4` | ✅ [BaseScan](https://basescan.org/address/0xA3D771bF986174D9cf9C85072cCD11cb72A694d4) |
| **PaymentRouter** | `0xc95D114A333d0394e562BD398c4787fd22d27110` | ✅ [BaseScan](https://basescan.org/address/0xc95D114A333d0394e562BD398c4787fd22d27110) |
| **Genesis** | `0xa23a81b1F7fB96DF6d12a579c2660b1ffbAAB2b7` | ✅ [BaseScan](https://basescan.org/address/0xa23a81b1F7fB96DF6d12a579c2660b1ffbAAB2b7) |
| **SmartAccountFactory** | `0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA` | ✅ [BaseScan](https://basescan.org/address/0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA) |
| **Treasury (SAFE)** | `0x4709280aef7A496EA84e72dB3CAbAd5e324d593e` | ✅ [BaseScan](https://basescan.org/address/0x4709280aef7A496EA84e72dB3CAbAd5e324d593e) |

---

## External Contracts

| Contract | Address |
|----------|---------|
| **USDC (Base)** | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| **Compound V3 cUSDCv3** | `0xb125E6687d4313864e53df431d5425969c15Eb2F` |

---

## NOVIS Token ABI

Key functions for integration:
```json
[
  {
    "name": "transfer",
    "type": "function",
    "inputs": [
      {"name": "to", "type": "address"},
      {"name": "amount", "type": "uint256"}
    ],
    "outputs": [{"type": "bool"}]
  },
  {
    "name": "balanceOf",
    "type": "function",
    "inputs": [{"name": "account", "type": "address"}],
    "outputs": [{"type": "uint256"}],
    "stateMutability": "view"
  },
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
    "name": "nonces",
    "type": "function",
    "inputs": [{"name": "owner", "type": "address"}],
    "outputs": [{"type": "uint256"}],
    "stateMutability": "view"
  },
  {
    "name": "metaTransferV2",
    "type": "function",
    "inputs": [
      {"name": "from", "type": "address"},
      {"name": "to", "type": "address"},
      {"name": "amount", "type": "uint256"},
      {"name": "nonce", "type": "uint256"},
      {"name": "deadline", "type": "uint256"},
      {"name": "signature", "type": "bytes"}
    ],
    "outputs": [{"type": "bool"}]
  }
]
```

---

## Vault ABI
```json
[
  {
    "name": "deposit",
    "type": "function",
    "inputs": [{"name": "usdcAmount", "type": "uint256"}],
    "outputs": []
  },
  {
    "name": "redeem",
    "type": "function",
    "inputs": [{"name": "novisAmount", "type": "uint256"}],
    "outputs": []
  },
  {
    "name": "totalBackingUSDC",
    "type": "function",
    "inputs": [],
    "outputs": [{"type": "uint256"}],
    "stateMutability": "view"
  }
]
```

---

## PaymentRouter ABI
```json
[
  {
    "name": "payWithMemo",
    "type": "function",
    "inputs": [
      {"name": "to", "type": "address"},
      {"name": "amount", "type": "uint256"},
      {"name": "memo", "type": "string"}
    ],
    "outputs": []
  },
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
    "name": "batchPay",
    "type": "function",
    "inputs": [
      {"name": "recipients", "type": "address[]"},
      {"name": "amounts", "type": "uint256[]"},
      {"name": "memos", "type": "string[]"}
    ],
    "outputs": []
  },
  {
    "name": "getEscrow",
    "type": "function",
    "inputs": [{"name": "escrowId", "type": "uint256"}],
    "outputs": [
      {"name": "payer", "type": "address"},
      {"name": "payee", "type": "address"},
      {"name": "amount", "type": "uint256"},
      {"name": "deadline", "type": "uint256"},
      {"name": "released", "type": "bool"},
      {"name": "refunded", "type": "bool"}
    ],
    "stateMutability": "view"
  }
]
```

---

## Genesis ABI
```json
[
  {
    "name": "programActive",
    "type": "function",
    "inputs": [],
    "outputs": [{"type": "bool"}],
    "stateMutability": "view"
  },
  {
    "name": "isGenesisHolder",
    "type": "function",
    "inputs": [{"name": "user", "type": "address"}],
    "outputs": [{"type": "bool"}],
    "stateMutability": "view"
  },
  {
    "name": "getClaimableYield",
    "type": "function",
    "inputs": [{"name": "user", "type": "address"}],
    "outputs": [{"type": "uint256"}],
    "stateMutability": "view"
  },
  {
    "name": "claimYield",
    "type": "function",
    "inputs": [],
    "outputs": []
  },
  {
    "name": "getGenesisCount",
    "type": "function",
    "inputs": [],
    "outputs": [{"type": "uint256"}],
    "stateMutability": "view"
  },
  {
    "name": "maxSpots",
    "type": "function",
    "inputs": [],
    "outputs": [{"type": "uint256"}],
    "stateMutability": "view"
  }
]
```

---

## EIP-712 Domain

For signing gasless transactions:
```javascript
const domain = {
  name: 'NOVIS',
  version: '1',
  chainId: 8453,
  verifyingContract: '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85'
};
```

---

## Network Config
```javascript
const config = {
  chainId: 8453,
  chainName: 'Base',
  rpcUrl: 'https://mainnet.base.org',
  blockExplorer: 'https://basescan.org',
  nativeCurrency: {
    name: 'Ethereum',
    symbol: 'ETH',
    decimals: 18
  }
};
```
