# @novis/sdk

Official JavaScript/TypeScript SDK for NOVIS protocol — gasless payments for AI agents on Base.

## Installation
```bash
npm install @novis/sdk
```

## Quick Start
```javascript
import { NOVISClient } from '@novis/sdk';

const client = new NOVISClient({ 
  privateKey: process.env.PRIVATE_KEY 
});

// Check balance
const balance = await client.getBalance();
console.log(`Balance: ${balance} NOVIS`);

// Send payment
await client.transfer('0xRecipient...', '100');
```

## Features

| Feature | Method | Description |
|---------|--------|-------------|
| **Transfer** | `transfer(to, amount)` | Send NOVIS tokens |
| **Gasless Transfer** | `transferGasless(to, amount)` | Send without paying gas |
| **Pay with Memo** | `payWithMemo(to, amount, memo)` | Attach reference to payment |
| **Batch Pay** | `batchPay([{to, amount, memo}])` | Pay multiple recipients |
| **Create Escrow** | `createEscrow(to, amount, timeout)` | Lock funds for task |
| **Release Escrow** | `releaseEscrow(escrowId)` | Release to payee |
| **Refund Escrow** | `refundEscrow(escrowId)` | Return to payer |
| **Mint** | `mint(usdcAmount)` | Deposit USDC → get NOVIS |
| **Redeem** | `redeem(novisAmount)` | Burn NOVIS → get USDC |

## Usage Examples

### Simple Transfer
```javascript
const client = new NOVISClient({ privateKey: '0x...' });

// Regular transfer
await client.transfer('0xRecipient...', '50');

// Gasless transfer (no ETH needed)
await client.transferGasless('0xRecipient...', '50');
```

### Payment with Memo
```javascript
// Attach task ID or reference
await client.payWithMemo(
  '0xRecipient...',
  '25',
  'task:summarize_document_abc123'
);
```

### Batch Payments
```javascript
// Pay multiple agents at once
await client.batchPay([
  { to: '0xAgentA...', amount: '10', memo: 'research' },
  { to: '0xAgentB...', amount: '20', memo: 'writing' },
  { to: '0xAgentC...', amount: '15', memo: 'review' }
]);
```

### Escrow
```javascript
// Create escrow (funds locked until release)
const { escrowId } = await client.createEscrow(
  '0xAgent...',
  '100',
  3600  // 1 hour timeout
);

// Check status
const escrow = await client.getEscrow(escrowId);
console.log(escrow);

// Release after task completion
await client.releaseEscrow(escrowId);

// Or refund if needed
await client.refundEscrow(escrowId);
```

### Mint & Redeem
```javascript
// Deposit 100 USDC → receive 100 NOVIS
await client.mint('100');

// Burn 50 NOVIS → receive 50 USDC
await client.redeem('50');
```

### Event Listeners
```javascript
// Listen for incoming payments
client.onPayment((payment) => {
  console.log(`Received ${payment.amount} NOVIS`);
  console.log(`Memo: ${payment.memo}`);
});

// Listen for new escrows
client.onEscrowCreated((escrow) => {
  console.log(`Escrow #${escrow.escrowId} created`);
});
```

## Contract Addresses

| Contract | Address |
|----------|---------|
| NOVIS Token | `0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85` |
| Vault | `0xA3D771bF986174D9cf9C85072cCD11cb72A694d4` |
| PaymentRouter | `0xc95D114A333d0394e562BD398c4787fd22d27110` |

## Network

- **Chain**: Base Mainnet
- **Chain ID**: 8453
- **RPC**: https://mainnet.base.org

## API Reference

### Constructor
```javascript
new NOVISClient({
  privateKey: string,    // Required: wallet private key
  rpcUrl?: string        // Optional: custom RPC URL
})
```

### Properties

- `client.address` — Wallet address

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getBalance(address?)` | `Promise<string>` | NOVIS balance |
| `getUSDCBalance(address?)` | `Promise<string>` | USDC balance |
| `getTotalBacking()` | `Promise<string>` | Total USDC in vault |
| `transfer(to, amount)` | `Promise<Receipt>` | Transfer NOVIS |
| `transferGasless(to, amount)` | `Promise<Receipt>` | Gasless transfer |
| `payWithMemo(to, amount, memo)` | `Promise<Receipt>` | Pay with reference |
| `batchPay(payments[])` | `Promise<Receipt>` | Batch payment |
| `createEscrow(to, amount, timeout)` | `Promise<{receipt, escrowId}>` | Create escrow |
| `releaseEscrow(escrowId)` | `Promise<Receipt>` | Release escrow |
| `refundEscrow(escrowId)` | `Promise<Receipt>` | Refund escrow |
| `getEscrow(escrowId)` | `Promise<Escrow>` | Get escrow details |
| `mint(usdcAmount)` | `Promise<Receipt>` | Mint NOVIS |
| `redeem(novisAmount)` | `Promise<Receipt>` | Redeem for USDC |

## License

MIT
