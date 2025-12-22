# NOVIS - Gasless Stablecoin for AI Agents

> The first stablecoin designed specifically for AI agent payments. Gasless transactions, escrow, and batch payments — no ETH required.

[![Base](https://img.shields.io/badge/Network-Base-0052FF)](https://base.org)
[![DefiLlama](https://img.shields.io/badge/Listed-DefiLlama-green)](https://defillama.com/protocol/novis)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 🚀 What is NOVIS?

NOVIS (NVS) is a **gasless, USDC-backed stablecoin** on Base designed for AI agent commerce. Agents can send payments, create escrows, and execute batch transfers without needing ETH for gas.

### Key Features

| Feature | Description |
|---------|-------------|
| **🔥 Gasless Transfers** | Sign and send — no ETH needed |
| **💰 1:1 USDC Backed** | 126%+ collateralized via Compound V3 |
| **📝 Payment Memos** | Attach references to payments (task IDs, invoices) |
| **🔒 Escrow** | Lock funds until task completion |
| **📦 Batch Payments** | Pay multiple recipients in one transaction |
| **🤖 Smart Accounts** | AI agent wallets with spending limits |

---

## 📍 Contract Addresses (Base Mainnet)

| Contract | Address | Description |
|----------|---------|-------------|
| **NOVIS Token** | `0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85` | ERC-20 with gasless support |
| **Vault** | `0xA3D771bF986174D9cf9C85072cCD11cb72A694d4` | Mint/redeem, USDC backing |
| **PaymentRouter** | `0xc95D114A333d0394e562BD398c4787fd22d27110` | Escrow, memos, batch payments |
| **Genesis** | `0xa23a81b1F7fB96DF6d12a579c2660b1ffbAAB2b7` | Early adopter yield program |
| **Smart Accounts** | `0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA` | AI agent account factory |
| **Treasury (SAFE)** | `0x4709280aef7A496EA84e72dB3CAbAd5e324d593e` | Protocol multisig |

### DEX Liquidity

| Pool | Type | Address |
|------|------|---------|
| **Aerodrome sAMM** | Stable (0.05% fee) | [NOVIS/USDC](https://aerodrome.finance/pools) |

---

## 🔧 Quick Start

### Install SDK
```bash
npm install @novis/sdk
# or
pip install novis-sdk
```

### Send Gasless Payment

**JavaScript:**
```javascript
import { NOVISClient } from '@novis/sdk';

const client = new NOVISClient({ privateKey: process.env.PRIVATE_KEY });

// Simple transfer (gasless)
await client.transfer('0xRecipient...', '100'); // 100 NOVIS

// Payment with memo
await client.payWithMemo('0xRecipient...', '50', 'task:summarize_doc_123');
```

**Python:**
```python
from novis import NOVISClient

client = NOVISClient(private_key=os.environ['PRIVATE_KEY'])

# Simple transfer (gasless)
client.transfer('0xRecipient...', 100)

# Payment with memo
client.pay_with_memo('0xRecipient...', 50, 'task:summarize_doc_123')
```

### Create Escrow (For Agent Tasks)
```javascript
// Create escrow — funds locked until release
const escrowId = await client.createEscrow({
  to: '0xAgentB...',
  amount: '100',
  timeout: 3600  // 1 hour
});

// After task completion — release funds
await client.releaseEscrow(escrowId);

// Or cancel/refund if needed
await client.refundEscrow(escrowId);
```

### Batch Payments
```javascript
// Pay multiple agents in one transaction
await client.batchPay([
  { to: '0xAgentA...', amount: '10', memo: 'task:research' },
  { to: '0xAgentB...', amount: '25', memo: 'task:writing' },
  { to: '0xAgentC...', amount: '15', memo: 'task:review' }
]);
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Quick Start](docs/quickstart.md) | Get started in 5 minutes |
| [JavaScript SDK](sdk/javascript/) | Full JS/TS documentation |
| [Python SDK](sdk/python/) | Full Python documentation |
| [Contract ABIs](contracts/abis/) | All contract interfaces |
| [Examples](examples/) | Working code samples |

---

## 🏗️ Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    AI AGENTS / USERS                        │
│                 (Sign transactions, no ETH)                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PAYMENT ROUTER                           │
│         Escrow • Memos • Batch Payments • Gasless           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      NOVIS TOKEN                            │
│              ERC-20 • Meta-transactions • Permit            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         VAULT                               │
│           Mint/Redeem 1:1 • USDC Backing • Yield            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    COMPOUND V3                              │
│                   ~5% APY on USDC                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔒 Security

- **Overcollateralized**: 126%+ USDC backing at all times
- **Verified Contracts**: All contracts verified on BaseScan
- **Multi-sig Control**: SAFE wallet (2/3) controls protocol
- **Auditable**: Open source, transparent on-chain
- **Upgradeable**: UUPS proxy for bug fixes without fund migration

---

## 🌐 Links

| Resource | Link |
|----------|------|
| **Website** | [novisdefi.com](https://novisdefi.com) |
| **Twitter** | [@NOVISdefi](https://twitter.com/NOVISdefi) |
| **DefiLlama** | [NOVIS Protocol](https://defillama.com/protocol/novis) |
| **BaseScan** | [Token](https://basescan.org/address/0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85) |
| **Aerodrome** | [Swap NOVIS](https://aerodrome.finance/swap?from=0x833589fcd6edb6e08f4c7c32d4f71b54bda02913&to=0x1fb5e1c0c3dec8da595e531b31c7b30c540e6b85) |

---

## 🤝 Integrations

NOVIS is designed for AI agent platforms. If you're building AI agents and need payment infrastructure:

1. Check out our [Integration Guide](docs/integration.md)
2. Use our [JavaScript SDK](sdk/javascript/) or [Python SDK](sdk/python/)
3. Reach out: [@NOVISdefi](https://twitter.com/NOVISdefi)

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

*Built for the AI agent economy* 🤖
