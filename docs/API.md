# NOVIS API Reference

> Complete API documentation for the NOVIS Relayer and Smart Contracts.

---

## Base URL

```
https://novis-relayer-production.up.railway.app
```

---

## Authentication

No authentication required. The relayer is permissionless.

---

## Endpoints

### GET /health

Check if the relayer is running.

**Request:**
```bash
curl https://novis-relayer-production.up.railway.app/health
```

**Response:**
```json
{
  "status": "ok",
  "relayer": "0xFBfFbfF486E6682e5d5b5e6BF87345285581Ec58"
}
```

---

### GET /nonce/:address

Get the current meta-transaction nonce for an address. Required for signing.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `address` | string | Ethereum address |

**Request:**
```bash
curl https://novis-relayer-production.up.railway.app/nonce/0x685F3040003E20Bf09488C8B9354913a00627f7a
```

**Response:**
```json
{
  "nonce": "5"
}
```

---

### GET /domain

Get the EIP-712 domain for signing meta-transfers.

**Request:**
```bash
curl https://novis-relayer-production.up.railway.app/domain
```

**Response:**
```json
{
  "name": "",
  "version": "",
  "chainId": "8453",
  "verifyingContract": "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85"
}
```

**Note:** Name and version are empty strings in the current implementation.

---

### GET /fee/:from/:to/:amount

Calculate the fee for a transfer before executing.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `from` | string | Sender address |
| `to` | string | Recipient address |
| `amount` | string | Amount in wei (18 decimals) |

**Request:**
```bash
curl https://novis-relayer-production.up.railway.app/fee/0x123.../0x456.../10000000000000000000
```

**Response:**
```json
{
  "amount": "10000000000000000000",
  "fee": "10000000000000000",
  "netAmount": "9990000000000000000",
  "feePercent": "0.1%"
}
```

**Fee Logic:**
- Amount < 10 NOVIS (10e18 wei): `fee = 0`, `feePercent = "0%"`
- Amount ≥ 10 NOVIS: `fee = amount * 0.001`, `feePercent = "0.1%"`

---

### POST /relay

Submit a signed meta-transfer for execution.

**Request Body:**
```json
{
  "from": "0x685F3040003E20Bf09488C8B9354913a00627f7a",
  "to": "0x9503c0681b4f7bFDc8C39cC1954A458009987Cb9",
  "amount": "10000000000000000000",
  "deadline": "1764328683",
  "signature": "0x4395578063c077187bae4e797bb6690ca00e7e4cce29918c038546801667d1de41c356b3f05fa90aa4e7a2c1d498d90d06a3b4c425634962d6fe11f9fbb1961f1b"
}
```

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `from` | string | Sender address (must match signer) |
| `to` | string | Recipient address |
| `amount` | string | Amount in wei (18 decimals) |
| `deadline` | string | Unix timestamp for signature expiry |
| `signature` | string | EIP-712 signature |

**Success Response:**
```json
{
  "success": true,
  "txHash": "0x4ff66392a4518587464fd70d301a002e5394e163b5922fe7d4b8f80a198fdb89",
  "blockNumber": 38770394
}
```

**Error Response:**
```json
{
  "error": "Invalid signature",
  "code": "INVALID_SIG"
}
```

---

## EIP-712 Signing

### TypedData Structure

```javascript
const domain = {
  name: "",
  version: "",
  chainId: 8453,
  verifyingContract: "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85"
};

const types = {
  MetaTransfer: [
    { name: "from", type: "address" },
    { name: "to", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" }
  ]
};

const message = {
  from: "0x...",
  to: "0x...",
  amount: BigInt("10000000000000000000"),
  nonce: BigInt(0),
  deadline: BigInt(Math.floor(Date.now() / 1000) + 3600)
};

const signature = await wallet.signTypedData(domain, types, message);
```

### Signing with ethers.js v6

```javascript
import { ethers } from 'ethers';

const wallet = new ethers.Wallet(privateKey);

const signature = await wallet.signTypedData(domain, types, message);
```

### Signing with viem

```javascript
import { signTypedData } from 'viem/accounts';

const signature = await signTypedData({
  domain,
  types,
  primaryType: 'MetaTransfer',
  message
});
```

---

## Smart Contract ABIs

### NOVIS Token

```javascript
const NOVIS_ABI = [
  // Read
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function allowance(address,address) view returns (uint256)",
  
  // Fee
  "function feeThreshold() view returns (uint256)",
  "function feePercentageBps() view returns (uint16)",
  "function feesEnabled() view returns (bool)",
  "function treasury() view returns (address)",
  "function totalFeesCollected() view returns (uint256)",
  "function calculateTransferFee(address,address,uint256) view returns (uint256,uint256)",
  
  // Meta-tx
  "function getMetaTxNonce(address) view returns (uint256)",
  "function getMetaTransferDigest(address,address,uint256,uint256,uint256) view returns (bytes32)",
  "function metaTransfer(address,address,uint256,uint256,bytes) returns (bool)",
  "function totalMetaTxRelayed() view returns (uint256)",
  
  // Write
  "function transfer(address,uint256) returns (bool)",
  "function approve(address,uint256) returns (bool)",
  "function transferFrom(address,address,uint256) returns (bool)",
  
  // EIP-2612 Permit
  "function permit(address,address,uint256,uint256,uint8,bytes32,bytes32)"
];
```

### Vault

```javascript
const VAULT_ABI = [
  // Read
  "function novisToken() view returns (address)",
  "function usdcToken() view returns (address)",
  "function totalAssets() view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function backingRatioBps() view returns (uint256)",
  "function bufferBps() view returns (uint256)",
  "function paused() view returns (bool)",
  "function version() view returns (string)",
  
  // Write
  "function deposit(uint256) returns (uint256)",
  "function redeem(uint256) returns (uint256)",
  "function buyAndBurn()",
  
  // Owner only
  "function pause()",
  "function unpause()",
  "function allocate(uint256)",
  "function deallocate(uint256)",
  "function rescueToken(address,uint256)",
  "function rescueETH(uint256)"
];
```

### Smart Account Factory

```javascript
const FACTORY_ABI = [
  "function createAccount(address,uint256,bytes32) returns (address)",
  "function accountCount() view returns (uint256)",
  "function accounts(uint256) view returns (address)",
  "function isAccount(address) view returns (bool)",
  "function getAccountsByOwner(address) view returns (address[])",
  "function accountImplementation() view returns (address)",
  "function entryPoint() view returns (address)",
  "function novisToken() view returns (address)"
];
```

### Smart Account

```javascript
const SMART_ACCOUNT_ABI = [
  // Read
  "function owner() view returns (address)",
  "function dailyLimit() view returns (uint256)",
  "function getDailySpending() view returns (uint256,uint256,uint256)",
  "function paused() view returns (bool)",
  
  // Write
  "function execute(address,uint256,bytes) returns (bytes)",
  
  // Owner only
  "function pause()",
  "function unpause()",
  "function setDailyLimit(uint256)",
  
  // ERC-4337
  "function validateUserOp(tuple,bytes32,uint256) returns (uint256)"
];
```

---

## Error Codes

| Code | Message | Description |
|------|---------|-------------|
| `INVALID_SIG` | Invalid signature | Signature doesn't match signer |
| `EXPIRED` | Signature expired | Deadline has passed |
| `INSUFFICIENT_BALANCE` | Insufficient balance | Sender lacks NOVIS |
| `NOT_RELAYER` | Not authorized relayer | Relaying is restricted |
| `DAILY_LIMIT` | Exceeds daily limit | Smart account limit hit |
| `PAUSED` | Account paused | Account is paused |

---

## Rate Limits

Currently no rate limits. This may change in the future.

---

## Examples

### cURL - Complete Flow

```bash
# 1. Check health
curl https://novis-relayer-production.up.railway.app/health

# 2. Get nonce
curl https://novis-relayer-production.up.railway.app/nonce/0xYourAddress

# 3. Get domain
curl https://novis-relayer-production.up.railway.app/domain

# 4. Check fee
curl https://novis-relayer-production.up.railway.app/fee/0xFrom/0xTo/10000000000000000000

# 5. Relay (with signed data)
curl -X POST https://novis-relayer-production.up.railway.app/relay \
  -H "Content-Type: application/json" \
  -d '{
    "from": "0x...",
    "to": "0x...",
    "amount": "10000000000000000000",
    "deadline": "1764328683",
    "signature": "0x..."
  }'
```

### JavaScript

See [JavaScript SDK](./sdk/javascript/novis-sdk.js) for complete implementation.

### Python

See [Python SDK](./sdk/python/novis_sdk.py) for complete implementation.

---

## Webhook (Future)

Webhook support for transaction notifications is planned for a future release.

---

## Support

For API issues:
- Check `/health` endpoint first
- Include full request/response in bug reports
- Open GitHub issue for bugs
