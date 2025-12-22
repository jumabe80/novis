# novis-sdk

Official Python SDK for NOVIS protocol — gasless payments for AI agents on Base.

## Installation
```bash
pip install novis-sdk
```

## Quick Start
```python
from novis import NOVISClient

client = NOVISClient(private_key='0x...')

# Check balance
balance = client.get_balance()
print(f"Balance: {balance} NOVIS")

# Send payment
client.transfer('0xRecipient...', 100)
```

## Features

| Feature | Method | Description |
|---------|--------|-------------|
| **Transfer** | `transfer(to, amount)` | Send NOVIS tokens |
| **Pay with Memo** | `pay_with_memo(to, amount, memo)` | Attach reference to payment |
| **Batch Pay** | `batch_pay([{to, amount, memo}])` | Pay multiple recipients |
| **Create Escrow** | `create_escrow(to, amount, timeout)` | Lock funds for task |
| **Release Escrow** | `release_escrow(escrow_id)` | Release to payee |
| **Refund Escrow** | `refund_escrow(escrow_id)` | Return to payer |
| **Mint** | `mint(usdc_amount)` | Deposit USDC → get NOVIS |
| **Redeem** | `redeem(novis_amount)` | Burn NOVIS → get USDC |

## Usage Examples

### Simple Transfer
```python
client = NOVISClient(private_key='0x...')

# Regular transfer
client.transfer('0xRecipient...', 50)
```

### Payment with Memo
```python
# Attach task ID or reference
client.pay_with_memo(
    '0xRecipient...',
    25,
    'task:summarize_document_abc123'
)
```

### Batch Payments
```python
# Pay multiple agents at once
client.batch_pay([
    {'to': '0xAgentA...', 'amount': 10, 'memo': 'research'},
    {'to': '0xAgentB...', 'amount': 20, 'memo': 'writing'},
    {'to': '0xAgentC...', 'amount': 15, 'memo': 'review'}
])
```

### Escrow
```python
# Create escrow (funds locked until release)
result = client.create_escrow(
    '0xAgent...',
    100,
    3600  # 1 hour timeout
)

# Check status
escrow = client.get_escrow(escrow_id)
print(escrow)

# Release after task completion
client.release_escrow(escrow_id)

# Or refund if needed
client.refund_escrow(escrow_id)
```

### Mint & Redeem
```python
# Deposit 100 USDC → receive 100 NOVIS
client.mint(100)

# Burn 50 NOVIS → receive 50 USDC
client.redeem(50)
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
```python
NOVISClient(
    private_key: str,    # Required: wallet private key
    rpc_url: str = None  # Optional: custom RPC URL
)
```

### Properties

- `client.address` — Wallet address

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `get_balance(address?)` | `float` | NOVIS balance |
| `get_usdc_balance(address?)` | `float` | USDC balance |
| `get_total_backing()` | `float` | Total USDC in vault |
| `transfer(to, amount)` | `dict` | Transfer NOVIS |
| `pay_with_memo(to, amount, memo)` | `dict` | Pay with reference |
| `batch_pay(payments)` | `dict` | Batch payment |
| `create_escrow(to, amount, timeout)` | `dict` | Create escrow |
| `release_escrow(escrow_id)` | `dict` | Release escrow |
| `refund_escrow(escrow_id)` | `dict` | Refund escrow |
| `get_escrow(escrow_id)` | `dict` | Get escrow details |
| `mint(usdc_amount)` | `dict` | Mint NOVIS |
| `redeem(novis_amount)` | `dict` | Redeem for USDC |

## License

MIT
