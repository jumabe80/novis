# NOVIS Contract Addresses

> All production contract addresses on Base Mainnet (Chain ID: 8453)

---

## ⚠️ Important

**Only use the addresses listed below.** Earlier versions are deprecated and should not be used.

---

## Core Contracts

### NOVIS Token (NVS)

| Property | Value |
|----------|-------|
| **Address** | `0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85` |
| **Symbol** | NVS |
| **Decimals** | 18 |
| **Type** | ERC-20 (Upgradeable UUPS) |
| **Version** | 2.0.0 |
| **Features** | Transfer fees, Meta-transactions, EIP-2612 Permit |
| **BaseScan** | [View on BaseScan](https://basescan.org/address/0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85) |

```javascript
const NOVIS_TOKEN = "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85";
```

---

### Vault

| Property | Value |
|----------|-------|
| **Address** | `0xA3D771bF986174D9cf9C85072cCD11cb72A694d4` |
| **Type** | Upgradeable UUPS |
| **Version** | 1.2.0 |
| **Purpose** | Deposit USDC, mint NOVIS, redeem, buy & burn |
| **BaseScan** | [View on BaseScan](https://basescan.org/address/0xA3D771bF986174D9cf9C85072cCD11cb72A694d4) |

```javascript
const VAULT = "0xA3D771bF986174D9cf9C85072cCD11cb72A694d4";
```

**Key Functions:**
- `deposit(uint256 usdcAmount)` - Deposit USDC, receive NOVIS
- `redeem(uint256 novisAmount)` - Burn NOVIS, receive USDC
- `buyAndBurn()` - Manual buy & burn trigger

---

### Yield Strategy (Compound V3)

| Property | Value |
|----------|-------|
| **Address** | `0x064E4586b7C63777BDC98A4776D3f78A93C0B752` |
| **Type** | Upgradeable UUPS |
| **Purpose** | Earn yield on USDC reserves via Compound V3 |
| **APY** | ~5% |
| **BaseScan** | [View on BaseScan](https://basescan.org/address/0x064E4586b7C63777BDC98A4776D3f78A93C0B752) |

```javascript
const STRATEGY = "0x064E4586b7C63777BDC98A4776D3f78A93C0B752";
```

---

### Smart Account Factory

| Property | Value |
|----------|-------|
| **Address** | `0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA` |
| **Purpose** | Creates ERC-4337 smart accounts for AI agents |
| **Implementation** | `0x5CdEFD283f134360f8D39b4672eBe84d03aa2d14` |
| **BaseScan** | [View on BaseScan](https://basescan.org/address/0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA) |

```javascript
const FACTORY = "0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA";
```

**Key Functions:**
- `createAccount(address owner, uint256 dailyLimit, bytes32 salt)` - Create smart account
- `accounts(uint256 index)` - Get account by index
- `accountCount()` - Total accounts created

---

### DEX Pool (Aerodrome)

| Property | Value |
|----------|-------|
| **Address** | `0xA0af1C990433102EFb08D78E060Ab05E6874ca69` |
| **Type** | Aerodrome Volatile Pool |
| **Pair** | NOVIS/USDC |
| **Purpose** | Trading, liquidity, buy & burn swaps |
| **BaseScan** | [View on BaseScan](https://basescan.org/address/0xA0af1C990433102EFb08D78E060Ab05E6874ca69) |

```javascript
const DEX_POOL = "0xA0af1C990433102EFb08D78E060Ab05E6874ca69";
```

---

### Treasury / SAFE Multi-sig

| Property | Value |
|----------|-------|
| **Address** | `0x4709280aef7A496EA84e72dB3CAbAd5e324d593e` |
| **Type** | SAFE Multi-signature Wallet |
| **Purpose** | Protocol owner, receives fees, controls upgrades |
| **BaseScan** | [View on BaseScan](https://basescan.org/address/0x4709280aef7A496EA84e72dB3CAbAd5e324d593e) |

```javascript
const TREASURY = "0x4709280aef7A496EA84e72dB3CAbAd5e324d593e";
```

---

### Relayer

| Property | Value |
|----------|-------|
| **Wallet** | `0xFBfFbfF486E6682e5d5b5e6BF87345285581Ec58` |
| **API URL** | `https://novis-relayer-production.up.railway.app` |
| **Purpose** | Executes gasless meta-transfers |

```javascript
const RELAYER_API = "https://novis-relayer-production.up.railway.app";
```

---

## External Dependencies

### USDC (Base)

| Property | Value |
|----------|-------|
| **Address** | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| **Decimals** | 6 |
| **Purpose** | Backing asset for NOVIS |

```javascript
const USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
```

### ERC-4337 EntryPoint

| Property | Value |
|----------|-------|
| **Address** | `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789` |
| **Version** | v0.6 |
| **Purpose** | Official ERC-4337 EntryPoint |

```javascript
const ENTRYPOINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
```

### Compound V3 Comet (USDC)

| Property | Value |
|----------|-------|
| **Address** | `0xb125E6687d4313864e53df431d5425969c15Eb2F` |
| **Purpose** | USDC lending market |

```javascript
const COMET = "0xb125E6687d4313864e53df431d5425969c15Eb2F";
```

### Aerodrome Router

| Property | Value |
|----------|-------|
| **Address** | `0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43` |
| **Purpose** | DEX swaps for buy & burn |

```javascript
const AERODROME_ROUTER = "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43";
```

---

## Quick Copy - All Addresses

### JavaScript

```javascript
// NOVIS Production Addresses (Base Mainnet)
const ADDRESSES = {
  // Core Protocol
  NOVIS_TOKEN: "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85",
  VAULT: "0xA3D771bF986174D9cf9C85072cCD11cb72A694d4",
  STRATEGY: "0x064E4586b7C63777BDC98A4776D3f78A93C0B752",
  FACTORY: "0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA",
  DEX_POOL: "0xA0af1C990433102EFb08D78E060Ab05E6874ca69",
  TREASURY: "0x4709280aef7A496EA84e72dB3CAbAd5e324d593e",
  
  // Infrastructure
  RELAYER_API: "https://novis-relayer-production.up.railway.app",
  RELAYER_WALLET: "0xFBfFbfF486E6682e5d5b5e6BF87345285581Ec58",
  ENTRYPOINT: "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
  
  // External
  USDC: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  COMET: "0xb125E6687d4313864e53df431d5425969c15Eb2F",
  AERODROME_ROUTER: "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43",
  
  // Network
  CHAIN_ID: 8453,
  RPC_URL: "https://mainnet.base.org"
};

export default ADDRESSES;
```

### Python

```python
# NOVIS Production Addresses (Base Mainnet)
ADDRESSES = {
    # Core Protocol
    "NOVIS_TOKEN": "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85",
    "VAULT": "0xA3D771bF986174D9cf9C85072cCD11cb72A694d4",
    "STRATEGY": "0x064E4586b7C63777BDC98A4776D3f78A93C0B752",
    "FACTORY": "0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA",
    "DEX_POOL": "0xA0af1C990433102EFb08D78E060Ab05E6874ca69",
    "TREASURY": "0x4709280aef7A496EA84e72dB3CAbAd5e324d593e",
    
    # Infrastructure
    "RELAYER_API": "https://novis-relayer-production.up.railway.app",
    "RELAYER_WALLET": "0xFBfFbfF486E6682e5d5b5e6BF87345285581Ec58",
    "ENTRYPOINT": "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    
    # External
    "USDC": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "COMET": "0xb125E6687d4313864e53df431d5425969c15Eb2F",
    "AERODROME_ROUTER": "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43",
    
    # Network
    "CHAIN_ID": 8453,
    "RPC_URL": "https://mainnet.base.org"
}
```

---

## Implementation Addresses (For Reference)

These are the implementation contracts behind the UUPS proxies:

| Contract | Implementation Address | Version |
|----------|----------------------|---------|
| NOVIS Token | `0x503B9dD4052624Af15D30575baaeb35E85B50b9d` | 2.0.0 |
| Vault | `0xF52Bd4A13d37aA22D4078D78639E4228316bC3ad` | 1.2.0 |
| Strategy | `0x9a1Ab8044cA77468c6Cfcb795B7d9D9Dc7c2Beab` | 1.0.0 |
| Smart Account | `0x5CdEFD283f134360f8D39b4672eBe84d03aa2d14` | 1.0.0 |

---

## Deprecated Addresses - DO NOT USE

| Contract | Address | Reason |
|----------|---------|--------|
| Old NOVIS V2 | `0x35C1Ec87f706dF616c67463A6f0fAe8Ae7E3d7b5` | Non-upgradeable |
| Old VaultV3 | `0x8fa4DDe3ca4977574d55368402281dCC6bFeA337` | Non-upgradeable |
| Old Strategy | `0x11552E6aA2614C7b4152bd8D4e61F31b831b259b` | Non-upgradeable |
| Old Pool | `0x4E79d91Dd8CC1AdbB2963dEf2c24ADa4f761bFDD` | Wrong token |
| Old NOVIS | `0x6af5e612fd96abf58086d30a12b5d46faa3581a6` | Deprecated |
| Old Factory V10 | `0x050b23172415e109F169d650493FEb0A65589327` | Uses old token |

---

## Verification

All contracts are verified on BaseScan. Source code available in this repository.
