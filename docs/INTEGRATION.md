# NOVIS Integration Guide

How to integrate NOVIS payments into your AI agent platform.

---

## Overview

NOVIS provides payment infrastructure for AI agents:

| Feature | Benefit |
|---------|---------|
| **Gasless** | Agents don't need ETH |
| **Escrow** | Safe task-based payments |
| **Memos** | Track payments by task ID |
| **Batch** | Pay multiple agents efficiently |

---

## Integration Options

### Option 1: Direct Contract Calls

Best for: Full control, custom implementations
```javascript
// Use ethers.js or web3.js directly
import { ethers } from 'ethers';

const NOVIS = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85';
const ROUTER = '0xc95D114A333d0394e562BD398c4787fd22d27110';
```

### Option 2: NOVIS SDK (Recommended)

Best for: Quick integration, less code
```javascript
// JavaScript
import { NOVISClient } from '@novis/sdk';

const client = new NOVISClient({ privateKey: process.env.PRIVATE_KEY });
await client.transfer('0x...', '100');
```
```python
# Python
from novis import NOVISClient

client = NOVISClient(private_key=os.environ['PRIVATE_KEY'])
client.transfer('0x...', 100)
```

---

## Step-by-Step Integration

### Step 1: Setup Wallet

Each AI agent needs a wallet (private key).
```javascript
import { ethers } from 'ethers';

// Generate new wallet for agent
const wallet = ethers.Wallet.createRandom();
console.log('Address:', wallet.address);
console.log('Private Key:', wallet.privateKey);
// Store privateKey securely!
```

### Step 2: Fund with NOVIS

Agent needs NOVIS tokens to make payments.

**Option A:** Transfer from your main wallet
**Option B:** User deposits USDC → mints NOVIS via Vault
**Option C:** Buy on Aerodrome DEX

### Step 3: Make Payments
```javascript
// Simple payment
await client.transfer(recipientAddress, amount);

// Payment with task reference
await client.payWithMemo(recipientAddress, amount, 'task:abc123');

// Escrow for task
const escrowId = await client.createEscrow(recipientAddress, amount, 3600);
// ... after task complete ...
await client.releaseEscrow(escrowId);
```

---

## Architecture Example
```
┌─────────────────────────────────────────────────────┐
│              YOUR AI AGENT PLATFORM                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │   Agent A   │  │   Agent B   │  │   Agent C   │ │
│  │  (wallet)   │  │  (wallet)   │  │  (wallet)   │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │
│         │                │                │        │
│         └────────────────┼────────────────┘        │
│                          │                         │
│                          ▼                         │
│                 ┌─────────────────┐                │
│                 │   NOVIS SDK     │                │
│                 └────────┬────────┘                │
│                          │                         │
└──────────────────────────┼─────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────┐
│                  BASE BLOCKCHAIN                     │
│                                                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────────┐ │
│  │   NOVIS    │  │  Payment   │  │     Vault      │ │
│  │   Token    │  │   Router   │  │  (USDC→NOVIS)  │ │
│  └────────────┘  └────────────┘  └────────────────┘ │
└──────────────────────────────────────────────────────┘
```

---

## Common Patterns

### Pattern 1: Task Payment Flow
```javascript
// 1. Agent A creates task for Agent B
const escrowId = await client.createEscrow(
  agentBAddress,
  '50',  // 50 NOVIS
  3600   // 1 hour timeout
);

// 2. Agent B performs task
const result = await agentB.performTask(taskDetails);

// 3. Agent A verifies and releases payment
if (verifyResult(result)) {
  await client.releaseEscrow(escrowId);
} else {
  // Wait for timeout, then refund
  await client.refundEscrow(escrowId);
}
```

### Pattern 2: Coordinator Agent
```javascript
// Coordinator pays multiple sub-agents
await client.batchPay([
  { to: researchAgent, amount: '20', memo: 'research:topic123' },
  { to: writingAgent, amount: '30', memo: 'writing:article456' },
  { to: reviewAgent, amount: '10', memo: 'review:draft789' }
]);
```

### Pattern 3: Micropayments
```javascript
// Pay per API call or per message
await client.payWithMemo(
  serviceAgent,
  '0.01',  // 0.01 NOVIS per call
  `api:${requestId}`
);
```

---

## Webhooks / Events

Monitor payments in real-time:
```javascript
const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const router = new ethers.Contract(ROUTER_ADDRESS, ROUTER_ABI, provider);

// Listen for incoming payments
router.on('PaymentWithMemo', (from, to, amount, memo) => {
  if (to.toLowerCase() === myAgentAddress.toLowerCase()) {
    console.log(`Received ${ethers.formatEther(amount)} NOVIS`);
    console.log(`Memo: ${memo}`);
    // Trigger task processing
    processTask(memo);
  }
});
```

---

## Security Best Practices

| Practice | Why |
|----------|-----|
| **Store keys securely** | Use environment variables or secret managers |
| **Use escrow for tasks** | Protects both parties |
| **Set reasonable timeouts** | Prevent funds being locked forever |
| **Validate memos** | Ensure memo format matches your system |
| **Monitor balances** | Alert when agent balance is low |

---

## Rate Limits & Costs

| Item | Value |
|------|-------|
| **Transfer fee** | FREE under 10 NOVIS, 0.1% above |
| **Gas cost** | ~$0.001 per tx on Base |
| **Escrow creation** | ~$0.002 per escrow |
| **No rate limits** | Blockchain has no API limits |

---

## Support

- **GitHub Issues**: [github.com/jumabe80/novis/issues](https://github.com/jumabe80/novis/issues)
- **Twitter**: [@NOVISdefi](https://twitter.com/NOVISdefi)
- **Examples**: See [/examples](../examples/) folder
