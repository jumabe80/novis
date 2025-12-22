/**
 * NOVIS Transfer Example
 * 
 * Send a gasless NOVIS transfer using meta-transactions.
 * 
 * Usage:
 *   PRIVATE_KEY=0x... node transfer.js <recipient> <amount>
 * 
 * Example:
 *   PRIVATE_KEY=0x... node transfer.js 0x1234...5678 100
 */

import { ethers } from 'ethers';

// Config
const NOVIS_TOKEN = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85';
const RPC_URL = 'https://mainnet.base.org';
const CHAIN_ID = 8453;

// ABI (only what we need)
const NOVIS_ABI = [
  'function balanceOf(address account) view returns (uint256)',
  'function nonces(address owner) view returns (uint256)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'function metaTransferV2(address from, address to, uint256 amount, uint256 nonce, uint256 deadline, bytes signature) returns (bool)'
];

// EIP-712 Domain
const DOMAIN = {
  name: 'NOVIS',
  version: '1',
  chainId: CHAIN_ID,
  verifyingContract: NOVIS_TOKEN
};

// EIP-712 Types
const TYPES = {
  MetaTransfer: [
    { name: 'from', type: 'address' },
    { name: 'to', type: 'address' },
    { name: 'amount', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
  ]
};

async function main() {
  // Parse args
  const recipient = process.argv[2];
  const amount = process.argv[3];

  if (!recipient || !amount) {
    console.log('Usage: PRIVATE_KEY=0x... node transfer.js <recipient> <amount>');
    console.log('Example: PRIVATE_KEY=0x... node transfer.js 0x1234...5678 100');
    process.exit(1);
  }

  if (!process.env.PRIVATE_KEY) {
    console.error('Error: PRIVATE_KEY environment variable required');
    process.exit(1);
  }

  // Setup
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const novis = new ethers.Contract(NOVIS_TOKEN, NOVIS_ABI, wallet);

  console.log('='.repeat(50));
  console.log('NOVIS Transfer');
  console.log('='.repeat(50));
  console.log(`From:   ${wallet.address}`);
  console.log(`To:     ${recipient}`);
  console.log(`Amount: ${amount} NOVIS`);
  console.log('='.repeat(50));

  // Check balance
  const balance = await novis.balanceOf(wallet.address);
  console.log(`Balance: ${ethers.formatEther(balance)} NOVIS`);

  const amountWei = ethers.parseEther(amount);
  if (balance < amountWei) {
    console.error('Error: Insufficient balance');
    process.exit(1);
  }

  // Get nonce
  const nonce = await novis.nonces(wallet.address);
  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour

  console.log(`Nonce:    ${nonce}`);
  console.log(`Deadline: ${new Date(deadline * 1000).toISOString()}`);

  // Sign meta-transfer
  console.log('\nSigning transaction...');
  const value = {
    from: wallet.address,
    to: recipient,
    amount: amountWei,
    nonce: nonce,
    deadline: deadline
  };

  const signature = await wallet.signTypedData(DOMAIN, TYPES, value);
  console.log(`Signature: ${signature.slice(0, 20)}...`);

  // Execute meta-transfer
  console.log('\nSending transaction...');
  const tx = await novis.metaTransferV2(
    wallet.address,
    recipient,
    amountWei,
    nonce,
    deadline,
    signature
  );

  console.log(`TX Hash: ${tx.hash}`);
  console.log('Waiting for confirmation...');

  const receipt = await tx.wait();
  console.log(`\n✅ Success! Block: ${receipt.blockNumber}`);
  console.log(`Gas used: ${receipt.gasUsed.toString()}`);

  // Check new balance
  const newBalance = await novis.balanceOf(wallet.address);
  console.log(`\nNew balance: ${ethers.formatEther(newBalance)} NOVIS`);
}

main().catch(console.error);
