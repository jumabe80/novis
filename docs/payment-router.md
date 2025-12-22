# PaymentRouter — Escrow, Memos & Batch Payments

The PaymentRouter enables advanced payment features for AI agents.

**Contract:** `0xc95D114A333d0394e562BD398c4787fd22d27110`

---

## Features

| Feature | Description | Use Case |
|---------|-------------|----------|
| **Pay with Memo** | Attach reference string to payment | Task IDs, invoices, receipts |
| **Escrow** | Lock funds until task completion | Agent-to-agent task payments |
| **Batch Payments** | Pay multiple recipients at once | Distribute to sub-agents |

---

## Pay with Memo

Attach a reference to any payment for tracking.
```javascript
import { ethers } from 'ethers';

const ROUTER = '0xc95D114A333d0394e562BD398c4787fd22d27110';
const NOVIS = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85';

const routerAbi = [
  'function payWithMemo(address to, uint256 amount, string memo)'
];
const tokenAbi = [
  'function approve(address spender, uint256 amount) returns (bool)'
];

const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

const router = new ethers.Contract(ROUTER, routerAbi, wallet);
const token = new ethers.Contract(NOVIS, tokenAbi, wallet);

// Approve router to spend NOVIS
await token.approve(ROUTER, ethers.parseEther('1000'));

// Pay with memo
await router.payWithMemo(
  '0xRecipient...',
  ethers.parseEther('50'),
  'task:summarize_document_abc123'
);
```

---

## Escrow

Lock funds until work is verified complete.

### Flow
```
1. Payer creates escrow (funds locked)
2. Payee does the work
3. Payer releases escrow (funds sent to payee)
   OR
   Timeout expires → Payer can refund
```

### Create Escrow
```javascript
const routerAbi = [
  'function createEscrow(address to, uint256 amount, uint256 timeout) returns (uint256)',
  'function releaseEscrow(uint256 escrowId)',
  'function refundEscrow(uint256 escrowId)',
  'function getEscrow(uint256 escrowId) view returns (address payer, address payee, uint256 amount, uint256 deadline, bool released, bool refunded)'
];

const router = new ethers.Contract(ROUTER, routerAbi, wallet);

// Create escrow — 100 NOVIS locked for 1 hour
const tx = await router.createEscrow(
  '0xAgentB...',           // payee
  ethers.parseEther('100'), // amount
  3600                      // timeout in seconds (1 hour)
);

const receipt = await tx.wait();
// Get escrowId from event logs
const escrowId = receipt.logs[0].args.escrowId;
console.log('Escrow created:', escrowId);
```

### Release Escrow (Task Complete)
```javascript
// After verifying work is done
await router.releaseEscrow(escrowId);
// Funds sent to payee
```

### Refund Escrow (Timeout/Cancel)
```javascript
// Only works after timeout OR if payer cancels
await router.refundEscrow(escrowId);
// Funds returned to payer
```

### Check Escrow Status
```javascript
const escrow = await router.getEscrow(escrowId);
console.log({
  payer: escrow.payer,
  payee: escrow.payee,
  amount: ethers.formatEther(escrow.amount),
  deadline: new Date(Number(escrow.deadline) * 1000),
  released: escrow.released,
  refunded: escrow.refunded
});
```

---

## Batch Payments

Pay multiple recipients in one transaction.
```javascript
const routerAbi = [
  'function batchPay(address[] recipients, uint256[] amounts, string[] memos)'
];

const router = new ethers.Contract(ROUTER, routerAbi, wallet);

// Pay 3 agents at once
await router.batchPay(
  [
    '0xAgentA...',
    '0xAgentB...',
    '0xAgentC...'
  ],
  [
    ethers.parseEther('10'),
    ethers.parseEther('25'),
    ethers.parseEther('15')
  ],
  [
    'task:research',
    'task:writing',
    'task:review'
  ]
);
```

---

## Events

Listen for payment events:
```javascript
const routerAbi = [
  'event PaymentWithMemo(address indexed from, address indexed to, uint256 amount, string memo)',
  'event EscrowCreated(uint256 indexed escrowId, address indexed payer, address indexed payee, uint256 amount, uint256 deadline)',
  'event EscrowReleased(uint256 indexed escrowId)',
  'event EscrowRefunded(uint256 indexed escrowId)'
];

const router = new ethers.Contract(ROUTER, routerAbi, provider);

// Listen for payments
router.on('PaymentWithMemo', (from, to, amount, memo) => {
  console.log(`Payment: ${from} → ${to}: ${ethers.formatEther(amount)} NOVIS`);
  console.log(`Memo: ${memo}`);
});

// Listen for escrows
router.on('EscrowCreated', (escrowId, payer, payee, amount, deadline) => {
  console.log(`Escrow #${escrowId} created: ${ethers.formatEther(amount)} NOVIS`);
});
```

---

## Python Example
```python
from web3 import Web3

ROUTER = '0xc95D114A333d0394e562BD398c4787fd22d27110'
w3 = Web3(Web3.HTTPProvider('https://mainnet.base.org'))

router_abi = [
    {
        "name": "payWithMemo",
        "type": "function",
        "inputs": [
            {"name": "to", "type": "address"},
            {"name": "amount", "type": "uint256"},
            {"name": "memo", "type": "string"}
        ]
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
    }
]

router = w3.eth.contract(address=ROUTER, abi=router_abi)

# Create escrow
tx = router.functions.createEscrow(
    '0xAgentB...',
    w3.to_wei(100, 'ether'),
    3600
).build_transaction({
    'from': account.address,
    'nonce': w3.eth.get_transaction_count(account.address)
})

signed = account.sign_transaction(tx)
tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
```

---

## Gasless Variants

All PaymentRouter functions have gasless variants using signatures. See [gasless.md](gasless.md) for details.
