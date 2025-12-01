# AI Agent Integration Guide

> Complete guide to integrate NOVIS gasless payments into your AI agent.

---

## Why NOVIS for AI Agents?

| Challenge | NOVIS Solution |
|-----------|----------------|
| Agents can't hold ETH | Gasless transfers - no ETH needed |
| Runaway spending | Daily spending limits |
| Security risks | Pause/unpause functionality |
| Complex setup | Simple SDK integration |

---

## Quick Start (5 Minutes)

### 1. Install SDK

**JavaScript:**
```bash
npm install ethers
# Copy novis-sdk.js to your project
```

**Python:**
```bash
pip install web3 eth-account requests
# Copy novis_sdk.py to your project
```

### 2. Initialize Client

**JavaScript:**
```javascript
import { NOVISClient } from './novis-sdk.js';

const novis = new NOVISClient(process.env.AI_AGENT_PRIVATE_KEY);
```

**Python:**
```python
from novis_sdk import NOVISClient

novis = NOVISClient(os.environ['AI_AGENT_PRIVATE_KEY'])
```

### 3. Send Payment

**JavaScript:**
```javascript
// No ETH needed - just sign and send!
const result = await novis.transfer(
  '0xServiceProvider...',  // Who to pay
  '5.0'                    // Amount in NOVIS
);
console.log('Paid! Tx:', result.txHash);
```

**Python:**
```python
result = novis.transfer(
    '0xServiceProvider...',
    '5.0'
)
print(f'Paid! Tx: {result.tx_hash}')
```

**That's it!** Your AI agent can now make payments without ETH.

---

## Architecture Options

### Option A: Direct Wallet (Simplest)

```
┌─────────────────┐
│    AI Agent     │
│                 │
│  Private Key    │────► Sign meta-transfer
│                 │            │
└─────────────────┘            │
                               ▼
                        ┌──────────────┐
                        │   Relayer    │────► Executes on-chain
                        └──────────────┘
```

**Pros:** Simple, no setup
**Cons:** If key is compromised, all funds at risk

**Best for:** Testing, low-value transactions

### Option B: Smart Account (Recommended for Production)

```
┌─────────────────┐
│    AI Agent     │
│                 │
│  Private Key    │────► Creates UserOperation
│                 │            │
└─────────────────┘            │
                               ▼
                        ┌──────────────┐
                        │   Pimlico    │────► Bundles & executes
                        │  (ERC-4337)  │
                        └──────────────┘
                               │
                               ▼
                        ┌──────────────┐
                        │Smart Account │
                        │              │
                        │ Daily Limit  │
                        │ Pause/Resume │
                        └──────────────┘
```

**Pros:** Spending limits, pausable, more secure
**Cons:** Requires account creation first

**Best for:** Production, high-value, multiple agents

---

## Detailed Integration

### Option A: Direct Wallet Integration

#### Step 1: Generate Agent Wallet

```javascript
import { ethers } from 'ethers';

// Generate new wallet for your agent
const wallet = ethers.Wallet.createRandom();
console.log('Address:', wallet.address);
console.log('Private Key:', wallet.privateKey);
// SAVE THE PRIVATE KEY SECURELY!
```

#### Step 2: Fund Agent Wallet

Transfer NOVIS to your agent's wallet address. The agent doesn't need ETH.

#### Step 3: Integrate into Agent

```javascript
// In your AI agent code
import { NOVISClient } from './novis-sdk.js';

class PaymentEnabledAgent {
  constructor(privateKey) {
    this.novis = new NOVISClient(privateKey);
  }
  
  async payForService(serviceAddress, amount, serviceDescription) {
    console.log(`Paying ${amount} NOVIS for: ${serviceDescription}`);
    
    // Check balance
    const balance = await this.novis.getBalance();
    if (parseFloat(balance) < parseFloat(amount)) {
      throw new Error(`Insufficient balance: ${balance} < ${amount}`);
    }
    
    // Execute payment
    const result = await this.novis.transfer(serviceAddress, amount);
    
    console.log(`Payment complete: ${result.txHash}`);
    return result;
  }
  
  async getBalance() {
    return await this.novis.getBalance();
  }
}

// Usage
const agent = new PaymentEnabledAgent(process.env.AGENT_PRIVATE_KEY);
await agent.payForService('0xAPI...', '1.0', 'API call to GPT-4');
```

### Option B: Smart Account Integration

#### Step 1: Create Smart Account (One-time Setup)

```javascript
import { NOVISClient } from './novis-sdk.js';

// Owner wallet (you) creates the smart account
const owner = new NOVISClient(process.env.OWNER_PRIVATE_KEY);

// Create account with 100 NOVIS/day limit
const accountAddress = await owner.createSmartAccount('100');
console.log('Smart Account:', accountAddress);

// Fund the account
await owner.fundSmartAccount(accountAddress, '500');
console.log('Funded with 500 NOVIS');
```

#### Step 2: Agent Uses Smart Account via Pimlico

```javascript
import { ethers } from 'ethers';

const PIMLICO_URL = `https://api.pimlico.io/v2/base/rpc?apikey=${PIMLICO_API_KEY}`;
const ENTRYPOINT = '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789';
const NOVIS = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85';

async function sendFromSmartAccount(smartAccountAddress, to, amount, agentPrivateKey) {
  const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
  const agent = new ethers.Wallet(agentPrivateKey, provider);
  
  // Build transfer calldata
  const novisInterface = new ethers.Interface([
    'function transfer(address,uint256) returns (bool)'
  ]);
  const transferData = novisInterface.encodeFunctionData('transfer', [
    to,
    ethers.parseEther(amount)
  ]);
  
  // Build execute calldata
  const accountInterface = new ethers.Interface([
    'function execute(address,uint256,bytes)'
  ]);
  const callData = accountInterface.encodeFunctionData('execute', [
    NOVIS, 0, transferData
  ]);
  
  // Get gas price from Pimlico
  const gasPriceRes = await fetch(PIMLICO_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0',
      method: 'pimlico_getUserOperationGasPrice',
      params: [],
      id: 1
    })
  });
  const gasPrices = (await gasPriceRes.json()).result.fast;
  
  // Build UserOperation
  let userOp = {
    sender: smartAccountAddress,
    nonce: '0x0', // Get actual nonce in production
    initCode: '0x',
    callData: callData,
    callGasLimit: '0x50000',
    verificationGasLimit: '0x60000',
    preVerificationGas: '0x10000',
    maxFeePerGas: gasPrices.maxFeePerGas,
    maxPriorityFeePerGas: gasPrices.maxPriorityFeePerGas,
    paymasterAndData: '0x',
    signature: '0x'
  };
  
  // Get sponsorship
  const sponsorRes = await fetch(PIMLICO_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0',
      method: 'pm_sponsorUserOperation',
      params: [userOp, ENTRYPOINT],
      id: 2
    })
  });
  const sponsor = (await sponsorRes.json()).result;
  userOp.paymasterAndData = sponsor.paymasterAndData;
  
  // Sign and submit
  // ... (see full example in /examples)
  
  return userOpHash;
}
```

---

## Common Patterns

### Pattern 1: Pay-per-API-Call

```javascript
async function callPaidAPI(apiUrl, payload) {
  // 1. Make payment
  const payment = await agent.payForService(
    API_PROVIDER_ADDRESS,
    '0.01',  // 0.01 NOVIS per call
    `API call to ${apiUrl}`
  );
  
  // 2. Include payment proof in request
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Payment-Tx': payment.txHash
    },
    body: JSON.stringify(payload)
  });
  
  return await response.json();
}
```

### Pattern 2: Subscription Payment

```javascript
async function payMonthlySubscription(serviceAddress, monthlyFee) {
  const balance = await agent.getBalance();
  
  if (parseFloat(balance) < parseFloat(monthlyFee)) {
    console.log('Low balance, requesting top-up...');
    // Notify owner to add funds
    return false;
  }
  
  const result = await agent.payForService(
    serviceAddress,
    monthlyFee,
    'Monthly subscription'
  );
  
  return result.success;
}
```

### Pattern 3: Multi-Agent Fleet

```javascript
class AgentFleet {
  constructor(agentKeys) {
    this.agents = agentKeys.map(key => new NOVISClient(key));
  }
  
  async getTotalBalance() {
    let total = 0;
    for (const agent of this.agents) {
      const balance = await agent.getBalance();
      total += parseFloat(balance);
    }
    return total;
  }
  
  async redistributeFunds(targetBalance) {
    // Balance funds across agents
    // ...
  }
}
```

---

## Security Best Practices

### 1. Key Management

```javascript
// ❌ BAD: Hardcoded key
const novis = new NOVISClient('0x1234...');

// ✅ GOOD: Environment variable
const novis = new NOVISClient(process.env.AGENT_PRIVATE_KEY);

// ✅ BETTER: Secret manager
const key = await secretManager.getSecret('agent-private-key');
const novis = new NOVISClient(key);
```

### 2. Use Smart Accounts for Production

```javascript
// Smart accounts provide:
// - Daily spending limits (e.g., 100 NOVIS/day)
// - Owner can pause if compromised
// - Owner can recover funds
```

### 3. Monitor Spending

```javascript
async function checkAgentHealth(agent) {
  const balance = await agent.getBalance();
  const threshold = 10; // NOVIS
  
  if (parseFloat(balance) < threshold) {
    alertOwner('Agent balance low: ' + balance);
  }
}
```

### 4. Handle Errors

```javascript
async function safeTransfer(agent, to, amount) {
  try {
    return await agent.transfer(to, amount);
  } catch (error) {
    if (error.message.includes('Insufficient balance')) {
      // Request top-up
      await requestTopUp(agent.address);
    } else if (error.message.includes('Daily limit')) {
      // Wait for reset or increase limit
      await notifyLimitReached(agent.address);
    }
    throw error;
  }
}
```

---

## Frameworks Integration

### LangChain

```python
from langchain.tools import Tool
from novis_sdk import NOVISClient

novis = NOVISClient(os.environ['PRIVATE_KEY'])

payment_tool = Tool(
    name="make_payment",
    description="Send NOVIS payment to an address",
    func=lambda args: novis.transfer(args['to'], args['amount'])
)

# Add to your agent's tools
agent = initialize_agent(
    tools=[payment_tool, ...],
    llm=llm,
    agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION
)
```

### AutoGPT

```python
# In your AutoGPT plugin
class NOVISPaymentPlugin:
    def __init__(self):
        self.client = NOVISClient(os.environ['AGENT_KEY'])
    
    def pay(self, address: str, amount: str, reason: str) -> dict:
        """Make a NOVIS payment."""
        result = self.client.transfer(address, amount)
        return {
            "success": result.success,
            "tx_hash": result.tx_hash,
            "reason": reason
        }
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Insufficient balance" | Fund agent wallet with NOVIS |
| "Invalid signature" | Check private key format |
| "Relay failed" | Check relayer status at /health |
| "Daily limit exceeded" | Wait for reset or increase limit |
| "Account paused" | Owner must unpause |

---

## Support

- **GitHub Issues**: Report bugs
- **Documentation**: Full API reference in /docs
- **Examples**: Ready-to-run code in /examples

---

*Built for autonomous AI agents* 🤖
