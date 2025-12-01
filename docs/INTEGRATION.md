# NOVIS Integration Guide

> Complete step-by-step guide to integrate NOVIS gasless transactions for your applications and AI agents.

---

## Overview

This guide covers two integration paths:

| Path | Best For | ETH Required | Complexity |
|------|----------|--------------|------------|
| **Meta-Transfer** | Regular users, simple apps | NO | Easy |
| **Smart Accounts** | AI agents, spending limits | NO | Medium |

**Time to integrate:** 15-30 minutes

---

## Prerequisites

- Node.js 18+ or Python 3.9+
- A wallet private key
- (Optional) Pimlico API key for Smart Accounts

---

## Path 1: Meta-Transfer (Gasless for Everyone)

This is the simplest integration. Users sign a message, your app sends it to our relayer, and the transfer happens without ETH.

### Step 1: Install SDK

```bash
npm install ethers
```

### Step 2: Basic Gasless Transfer

```javascript
import { ethers } from 'ethers';

const RELAYER_URL = "https://novis-relayer-production.up.railway.app";
const NOVIS = "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85";

async function gaslessTransfer(privateKey, to, amount) {
  const provider = new ethers.JsonRpcProvider("https://mainnet.base.org");
  const wallet = new ethers.Wallet(privateKey, provider);
  
  // 1. Get nonce from relayer
  const nonceRes = await fetch(`${RELAYER_URL}/nonce/${wallet.address}`);
  const { nonce } = await nonceRes.json();
  
  // 2. Get domain from relayer
  const domainRes = await fetch(`${RELAYER_URL}/domain`);
  const domainData = await domainRes.json();
  
  // 3. Prepare transfer
  const amountWei = ethers.parseEther(amount);
  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
  
  // 4. Sign EIP-712 typed data
  const domain = {
    name: domainData.name,
    version: domainData.version,
    chainId: BigInt(domainData.chainId),
    verifyingContract: domainData.verifyingContract
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
    from: wallet.address,
    to: to,
    amount: amountWei,
    nonce: BigInt(nonce),
    deadline: BigInt(deadline)
  };
  
  const signature = await wallet.signTypedData(domain, types, message);
  
  // 5. Send to relayer
  const response = await fetch(`${RELAYER_URL}/relay`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: wallet.address,
      to: to,
      amount: amountWei.toString(),
      deadline: deadline.toString(),
      signature: signature
    })
  });
  
  return await response.json();
}

// Usage
const result = await gaslessTransfer(
  process.env.PRIVATE_KEY,
  "0xRecipientAddress...",
  "10.0"  // 10 NOVIS
);
console.log("Tx:", result.txHash);
```

### Step 3: Check Fee Before Transfer

```javascript
async function checkFee(from, to, amount) {
  const amountWei = ethers.parseEther(amount);
  const response = await fetch(
    `${RELAYER_URL}/fee/${from}/${to}/${amountWei}`
  );
  return await response.json();
}

// Returns: { amount, fee, netAmount, feePercent }
const feeInfo = await checkFee(wallet.address, recipient, "100");
console.log(feeInfo);
// { amount: "100000...", fee: "100...", netAmount: "99900...", feePercent: "0.1%" }
```

---

## Path 2: Smart Accounts (For AI Agents)

Smart Accounts provide:
- Daily spending limits
- Pause/unpause functionality
- ERC-4337 compatibility
- Pimlico gas sponsorship

### Step 1: Create Smart Account

```javascript
import { ethers } from 'ethers';

const FACTORY = "0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA";
const RPC_URL = "https://mainnet.base.org";

async function createSmartAccount(privateKey, dailyLimitNovis) {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);
  
  const factory = new ethers.Contract(FACTORY, [
    "function createAccount(address,uint256,bytes32) returns (address)",
    "function accountCount() view returns (uint256)",
    "function accounts(uint256) view returns (address)"
  ], wallet);
  
  // Daily limit in wei (18 decimals)
  const dailyLimitWei = ethers.parseEther(dailyLimitNovis);
  
  // Unique salt
  const salt = ethers.keccak256(
    ethers.toUtf8Bytes(Date.now().toString())
  );
  
  // Create account
  const tx = await factory.createAccount(
    wallet.address,
    dailyLimitWei,
    salt
  );
  await tx.wait();
  
  // Get account address
  const count = await factory.accountCount();
  const accountAddress = await factory.accounts(count - 1n);
  
  console.log("Smart Account created:", accountAddress);
  return accountAddress;
}

// Create account with 100 NOVIS/day limit
const account = await createSmartAccount(process.env.PRIVATE_KEY, "100");
```

### Step 2: Fund Smart Account

```javascript
const NOVIS = "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85";

async function fundSmartAccount(privateKey, accountAddress, amount) {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);
  
  const novis = new ethers.Contract(NOVIS, [
    "function transfer(address,uint256) returns (bool)"
  ], wallet);
  
  const amountWei = ethers.parseEther(amount);
  const tx = await novis.transfer(accountAddress, amountWei);
  await tx.wait();
  
  console.log("Funded:", amount, "NOVIS");
}

await fundSmartAccount(process.env.PRIVATE_KEY, account, "50");
```

### Step 3: Execute via Smart Account

```javascript
async function executeFromSmartAccount(privateKey, accountAddress, to, amount) {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);
  
  const smartAccount = new ethers.Contract(accountAddress, [
    "function execute(address,uint256,bytes) returns (bytes)"
  ], wallet);
  
  // Build NOVIS transfer calldata
  const novisInterface = new ethers.Interface([
    "function transfer(address,uint256) returns (bool)"
  ]);
  const transferData = novisInterface.encodeFunctionData("transfer", [
    to,
    ethers.parseEther(amount)
  ]);
  
  // Execute
  const tx = await smartAccount.execute(NOVIS, 0, transferData);
  await tx.wait();
  
  console.log("Transfer executed:", tx.hash);
}

await executeFromSmartAccount(
  process.env.PRIVATE_KEY,
  account,
  "0xRecipient...",
  "10"
);
```

### Step 4: Gasless via Pimlico (No ETH Needed)

```javascript
const PIMLICO_API_KEY = process.env.PIMLICO_API_KEY;
const PIMLICO_URL = `https://api.pimlico.io/v2/base/rpc?apikey=${PIMLICO_API_KEY}`;
const ENTRYPOINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";

async function gaslessSmartAccountTransfer(privateKey, accountAddress, to, amount) {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(privateKey, provider);
  
  // Build calldata
  const novisInterface = new ethers.Interface([
    "function transfer(address,uint256) returns (bool)"
  ]);
  const transferData = novisInterface.encodeFunctionData("transfer", [
    to,
    ethers.parseEther(amount)
  ]);
  
  const accountInterface = new ethers.Interface([
    "function execute(address,uint256,bytes)"
  ]);
  const callData = accountInterface.encodeFunctionData("execute", [
    NOVIS,
    0,
    transferData
  ]);
  
  // Get gas prices from Pimlico
  const gasPriceRes = await fetch(PIMLICO_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "pimlico_getUserOperationGasPrice",
      params: [],
      id: 1
    })
  });
  const gasPrices = (await gasPriceRes.json()).result.fast;
  
  // Build UserOperation
  let userOp = {
    sender: accountAddress,
    nonce: "0x0",
    initCode: "0x",
    callData: callData,
    callGasLimit: "0x50000",
    verificationGasLimit: "0x60000",
    preVerificationGas: "0x10000",
    maxFeePerGas: gasPrices.maxFeePerGas,
    maxPriorityFeePerGas: gasPrices.maxPriorityFeePerGas,
    paymasterAndData: "0x",
    signature: "0x"
  };
  
  // Get sponsorship
  const sponsorRes = await fetch(PIMLICO_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "pm_sponsorUserOperation",
      params: [userOp, ENTRYPOINT],
      id: 2
    })
  });
  const sponsor = (await sponsorRes.json()).result;
  
  userOp.paymasterAndData = sponsor.paymasterAndData;
  userOp.preVerificationGas = sponsor.preVerificationGas;
  userOp.verificationGasLimit = sponsor.verificationGasLimit;
  userOp.callGasLimit = sponsor.callGasLimit;
  
  // Sign and submit (simplified - see full SDK for complete implementation)
  // ...
  
  return userOpHash;
}
```

---

## API Reference

### Relayer Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Check relayer status |
| `/nonce/:address` | GET | Get meta-tx nonce for address |
| `/domain` | GET | Get EIP-712 domain |
| `/fee/:from/:to/:amount` | GET | Calculate transfer fee |
| `/relay` | POST | Submit signed meta-transfer |

### POST /relay

**Request Body:**
```json
{
  "from": "0x...",
  "to": "0x...",
  "amount": "1000000000000000000",
  "deadline": "1764328683",
  "signature": "0x..."
}
```

**Response:**
```json
{
  "success": true,
  "txHash": "0x...",
  "blockNumber": 12345678
}
```

---

## Fee Structure

| Amount | Fee | Example |
|--------|-----|---------|
| < 10 NOVIS | FREE | 5 NOVIS → 5 NOVIS |
| ≥ 10 NOVIS | 0.1% | 100 NOVIS → 99.9 NOVIS |

Fees go to the Treasury and fund gas sponsorship.

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Invalid sig" | Wrong signature | Check EIP-712 domain matches |
| "Expired" | Deadline passed | Use longer deadline |
| "Not relayer" | Relayer not authorized | Contact support |
| "Exceeds daily limit" | Smart account limit hit | Wait for reset or increase limit |
| "Account paused" | Account is paused | Owner must unpause |

### Example Error Handling

```javascript
try {
  const result = await gaslessTransfer(key, to, "10");
  console.log("Success:", result.txHash);
} catch (error) {
  if (error.message.includes("Invalid sig")) {
    console.error("Signature verification failed");
  } else if (error.message.includes("Expired")) {
    console.error("Transaction deadline expired, retry");
  } else {
    console.error("Unknown error:", error.message);
  }
}
```

---

## Security Best Practices

### For Regular Wallets
1. Never expose private keys in client-side code
2. Use environment variables for sensitive data
3. Validate recipient addresses before signing

### For AI Agents / Smart Accounts
1. Set appropriate daily limits
2. Monitor spending regularly
3. Use unique private keys per agent
4. Implement pause functionality
5. Keep owner key secure (offline if possible)

---

## Testing

### Check Balance

```javascript
async function getBalance(address) {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const novis = new ethers.Contract(NOVIS, [
    "function balanceOf(address) view returns (uint256)"
  ], provider);
  
  const balance = await novis.balanceOf(address);
  return ethers.formatEther(balance);
}

console.log(await getBalance("0xYourAddress..."));
```

### Verify Transaction

```javascript
async function verifyTx(txHash) {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const receipt = await provider.getTransactionReceipt(txHash);
  
  console.log("Status:", receipt.status === 1 ? "Success" : "Failed");
  console.log("Block:", receipt.blockNumber);
  console.log("Gas Used:", receipt.gasUsed.toString());
}
```

---

## Full Working Example

See `/examples/complete-integration.js` for a full working example including:
- Wallet setup
- Balance checking
- Fee preview
- Gasless transfer
- Error handling
- Transaction verification

---

## Support

- **GitHub Issues**: Report bugs or request features
- **Documentation**: Check `/docs` for detailed guides
- **Examples**: See `/examples` for ready-to-use code

---

## Next Steps

1. [View Contract Addresses](./CONTRACTS.md)
2. [API Documentation](./API.md)
3. [JavaScript SDK](./sdk/javascript/)
4. [Python SDK](./sdk/python/)
5. [Code Examples](./examples/)
