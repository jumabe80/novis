# NOVIS - AI-Native Stablecoin

> The first stablecoin designed specifically for AI agents. Gasless transactions for everyone - humans and AI alike.

[![Base](https://img.shields.io/badge/Network-Base-0052FF)](https://base.org)
[![ERC-4337](https://img.shields.io/badge/ERC--4337-Compatible-green)](https://eips.ethereum.org/EIPS/eip-4337)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 🚀 What is NOVIS?

NOVIS (NVS) is a **gasless, overcollateralized stablecoin** built on Base. Users and AI agents can transfer NOVIS without needing ETH for gas - they just sign, and our relayer handles the rest.

### Key Features

| Feature | Description |
|---------|-------------|
| **🔥 Gasless for Everyone** | Humans and AI agents transfer without ETH |
| **💰 1:1 USDC Backing** | Fully collateralized, always redeemable |
| **📈 Auto Buy & Burn** | Yield generates deflationary pressure |
| **🤖 AI-Native** | Smart Accounts with spending limits |
| **🔒 Upgradeable** | UUPS proxy pattern for future improvements |
| **⚡ Low Fees** | FREE under 10 NOVIS, 0.1% above |

---

## 📊 How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    USER EXPERIENCE                          │
│                    (Frictionless)                           │
│                                                             │
│   User/AI signs transfer                                    │
│         │                                                   │
│         ▼                                                   │
│   Relayer submits tx (pays gas)                            │
│         │                                                   │
│         ▼                                                   │
│   Recipient gets NOVIS (minus 0.1% fee if ≥10)             │
│                                                             │
│   User thinks: "Wow, no gas needed!"                       │
└─────────────────────────────────────────────────────────────┘
```

### The Economics

| Transaction | Fee Collected | Gas Cost (approx) | Net Revenue |
|-------------|---------------|-------------------|-------------|
| Send 100 NOVIS | 0.1 NOVIS (~$0.10) | ~$0.001 on Base | +$0.099 |
| Send 1000 NOVIS | 1 NOVIS (~$1.00) | ~$0.001 on Base | +$0.999 |
| Send 5 NOVIS | FREE | ~$0.001 on Base | Subsidized |

---

## 💸 Fee Structure

| Transfer Amount | Fee | Example |
|-----------------|-----|---------|
| < 10 NOVIS | **FREE** | Send 5 NOVIS → Receive 5 NOVIS |
| ≥ 10 NOVIS | **0.1%** | Send 100 NOVIS → Receive 99.9 NOVIS |

*Fees are configurable and fund gas sponsorship + protocol development.*

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         USERS                                │
│              (Humans via MetaMask, AI Agents)                │
└──────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────────┐
│     META-TRANSFER       │     │      SMART ACCOUNTS         │
│   (Regular Wallets)     │     │     (AI Agents/ERC-4337)    │
│                         │     │                             │
│  Sign EIP-712 message   │     │  UserOperation via Pimlico  │
│  → Relayer executes     │     │  → Bundler executes         │
└───────────┬─────────────┘     └──────────────┬──────────────┘
            │                                   │
            └───────────────┬───────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                      NOVIS TOKEN                             │
│                   (Upgradeable ERC-20)                       │
│                                                              │
│  • Transfer fees (0.1% ≥ 10 NOVIS)                          │
│  • Meta-transaction support (gasless)                        │
│  • EIP-2612 Permit (gasless approvals)                      │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                        VAULT                                 │
│                                                              │
│  • Deposit USDC → Mint NOVIS (1:1)                          │
│  • Redeem NOVIS → Get USDC (1:1)                            │
│  • Auto Buy & Burn from yield                               │
│  • Auto-deallocate from strategy on redeem                  │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                   YIELD STRATEGY                             │
│                   (Compound V3)                              │
│                                                              │
│  • USDC earns ~5% APY                                       │
│  • Yield funds Buy & Burn                                   │
│  • Deflationary token supply over time                      │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔧 Quick Start

### Option 1: Gasless Transfer (Recommended)

No ETH needed - just sign and send!

```javascript
import { NOVISClient } from './novis-sdk.js';

const novis = new NOVISClient(process.env.PRIVATE_KEY);

// Send gasless transfer
const result = await novis.transfer(
  '0xRecipientAddress...',
  '10.0'  // 10 NOVIS
);

console.log('Success:', result.txHash);
// User paid 0 ETH for gas
// 0.01 NOVIS fee deducted (0.1% of 10)
```

### Option 2: Smart Account (For AI Agents)

Create a smart account with spending limits:

```javascript
import { NOVISClient } from './novis-sdk.js';

const novis = new NOVISClient(process.env.PRIVATE_KEY);

// Create smart account with 100 NOVIS/day limit
const accountAddress = await novis.createSmartAccount('100');

console.log('Smart Account:', accountAddress);

// Fund it
await novis.fundSmartAccount(accountAddress, '50');

// Now AI agent can transact via Pimlico (gasless)
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Contract Addresses](./CONTRACTS.md) | All deployed contracts on Base |
| [Integration Guide](./INTEGRATION.md) | Step-by-step setup for developers |
| [API Reference](./API.md) | Relayer API documentation |
| [JavaScript SDK](./sdk/javascript/) | Full JS/TS SDK |
| [Python SDK](./sdk/python/) | Full Python SDK |
| [Examples](./examples/) | Ready-to-run code samples |

---

## 📍 Contract Addresses (Base Mainnet)

| Contract | Address | Purpose |
|----------|---------|---------|
| **NOVIS Token** | `0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85` | ERC-20 token with gasless support |
| **Vault** | `0xA3D771bF986174D9cf9C85072cCD11cb72A694d4` | Deposit/redeem, buy & burn |
| **Strategy** | `0x064E4586b7C63777BDC98A4776D3f78A93C0B752` | Compound V3 yield |
| **Smart Account Factory** | `0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA` | Creates AI agent accounts |
| **DEX Pool** | `0xA0af1C990433102EFb08D78E060Ab05E6874ca69` | Aerodrome NOVIS/USDC |
| **Treasury/SAFE** | `0x4709280aef7A496EA84e72dB3CAbAd5e324d593e` | Protocol owner |
| **Relayer API** | `https://novis-relayer-production.up.railway.app` | Gasless transaction relay |

---

## 🔒 Security

- **Overcollateralized**: Always ≥100% USDC backing
- **Multi-sig Control**: SAFE wallet controls all protocol functions
- **Upgradeable**: UUPS proxy pattern allows bug fixes without fund migration
- **Rescue Functions**: Stuck tokens can always be recovered
- **Spending Limits**: Smart accounts have daily limits to protect AI agents
- **Pausable**: Emergency pause available on vault and accounts
- **Open Source**: All contracts verified on BaseScan

---

## 🌐 Network Details

| Property | Value |
|----------|-------|
| Network | Base Mainnet |
| Chain ID | 8453 |
| Token Symbol | NVS |
| Token Decimals | 18 |
| RPC URL | https://mainnet.base.org |

---

## 🔗 Links

- [BaseScan - NOVIS Token](https://basescan.org/address/0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85)
- [BaseScan - Vault](https://basescan.org/address/0xA3D771bF986174D9cf9C85072cCD11cb72A694d4)
- [Aerodrome DEX](https://aerodrome.finance)
- [Base Network](https://base.org)
- [Pimlico (ERC-4337)](https://pimlico.io)

---

## 🛠️ Development

### Prerequisites

- Node.js 18+ or Python 3.9+
- A wallet with NOVIS tokens
- (Optional) Pimlico API key for Smart Accounts

### Local Setup

```bash
# Clone repository
git clone https://github.com/your-org/novis.git
cd novis

# Install dependencies
npm install

# Set environment
cp .env.example .env
# Edit .env with your keys

# Run examples
node examples/transfer.js
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

## 📞 Support

- **GitHub Issues**: Bug reports and feature requests
- **Documentation**: Full guides in `/docs`

---

*Built for the AI-powered future* 🤖
