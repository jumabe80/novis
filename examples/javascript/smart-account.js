/**
 * NOVIS Smart Account Example
 * 
 * Create and manage AI agent smart accounts with spending limits.
 * 
 * Usage:
 *   PRIVATE_KEY=0x... node smart-account.js create <daily_limit>
 *   PRIVATE_KEY=0x... node smart-account.js fund <account_address> <amount>
 *   PRIVATE_KEY=0x... node smart-account.js info <account_address>
 */

import { ethers } from 'ethers';

// Config
const NOVIS_TOKEN = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85';
const SMART_ACCOUNT_FACTORY = '0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA';
const RPC_URL = 'https://mainnet.base.org';

// ABIs
const TOKEN_ABI = [
  'function transfer(address to, uint256 amount) returns (bool)',
  'function balanceOf(address account) view returns (uint256)'
];

const FACTORY_ABI = [
  'function createAccount(address owner, uint256 dailyLimit) returns (address)',
  'function getAccount(address owner) view returns (address)',
  'event AccountCreated(address indexed owner, address indexed account, uint256 dailyLimit)'
];

const SMART_ACCOUNT_ABI = [
  'function owner() view returns (address)',
  'function dailyLimit() view returns (uint256)',
  'function spentToday() view returns (uint256)',
  'function lastSpendDate() view returns (uint256)',
  'function execute(address to, uint256 value, bytes data) returns (bytes)',
  'function setDailyLimit(uint256 newLimit)'
];

async function createSmartAccount(wallet, dailyLimit) {
  const factory = new ethers.Contract(SMART_ACCOUNT_FACTORY, FACTORY_ABI, wallet);

  console.log('Creating smart account...');
  console.log(`  Owner: ${wallet.address}`);
  console.log(`  Daily Limit: ${dailyLimit} NOVIS`);

  const limitWei = ethers.parseEther(dailyLimit);
  const tx = await factory.createAccount(wallet.address, limitWei);
  console.log(`TX Hash: ${tx.hash}`);

  const receipt = await tx.wait();

  // Parse account address from event
  let accountAddress = null;
  for (const log of receipt.logs) {
    try {
      const parsed = factory.interface.parseLog(log);
      if (parsed?.name === 'AccountCreated') {
        accountAddress = parsed.args.account;
        break;
      }
    } catch {}
  }

  if (accountAddress) {
    console.log(`\n✅ Smart Account created!`);
    console.log(`   Address: ${accountAddress}`);
    console.log(`\nNext steps:`);
    console.log(`  1. Fund it: node smart-account.js fund ${accountAddress} 100`);
    console.log(`  2. Use it for AI agent transactions`);
  } else {
    // Try to get existing account
    accountAddress = await factory.getAccount(wallet.address);
    console.log(`\n⚠️ Account may already exist: ${accountAddress}`);
  }
}

async function fundSmartAccount(wallet, accountAddress, amount) {
  const token = new ethers.Contract(NOVIS_TOKEN, TOKEN_ABI, wallet);

  console.log('Funding smart account...');
  console.log(`  Account: ${accountAddress}`);
  console.log(`  Amount: ${amount} NOVIS`);

  const amountWei = ethers.parseEther(amount);
  const tx = await token.transfer(accountAddress, amountWei);
  console.log(`TX Hash: ${tx.hash}`);

  await tx.wait();
  console.log(`\n✅ Funded successfully!`);

  // Check new balance
  const balance = await token.balanceOf(accountAddress);
  console.log(`Account balance: ${ethers.formatEther(balance)} NOVIS`);
}

async function getAccountInfo(provider, accountAddress) {
  const token = new ethers.Contract(NOVIS_TOKEN, TOKEN_ABI, provider);
  const account = new ethers.Contract(accountAddress, SMART_ACCOUNT_ABI, provider);

  console.log('Smart Account Info');
  console.log('='.repeat(50));
  console.log(`Address: ${accountAddress}`);

  try {
    const owner = await account.owner();
    const dailyLimit = await account.dailyLimit();
    const spentToday = await account.spentToday();
    const balance = await token.balanceOf(accountAddress);

    console.log(`Owner: ${owner}`);
    console.log(`Balance: ${ethers.formatEther(balance)} NOVIS`);
    console.log(`Daily Limit: ${ethers.formatEther(dailyLimit)} NOVIS`);
    console.log(`Spent Today: ${ethers.formatEther(spentToday)} NOVIS`);
    console.log(`Remaining: ${ethers.formatEther(dailyLimit - spentToday)} NOVIS`);
  } catch (e) {
    console.log(`\n⚠️ Could not read account info. Is this a valid smart account?`);
    console.log(`   Error: ${e.message}`);
  }
}

async function main() {
  const command = process.argv[2];

  if (!command || !['create', 'fund', 'info'].includes(command)) {
    console.log('NOVIS Smart Account Manager');
    console.log('='.repeat(50));
    console.log('Usage:');
    console.log('  node smart-account.js create <daily_limit>');
    console.log('  node smart-account.js fund <account_address> <amount>');
    console.log('  node smart-account.js info <account_address>');
    console.log('');
    console.log('Examples:');
    console.log('  node smart-account.js create 100        # Create with 100 NOVIS/day limit');
    console.log('  node smart-account.js fund 0x... 50     # Fund with 50 NOVIS');
    console.log('  node smart-account.js info 0x...        # Get account info');
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(RPC_URL);

  if (command === 'info') {
    const accountAddress = process.argv[3];
    if (!accountAddress) {
      console.error('Error: account_address required');
      process.exit(1);
    }
    await getAccountInfo(provider, accountAddress);
    return;
  }

  // Other commands need private key
  if (!process.env.PRIVATE_KEY) {
    console.error('Error: PRIVATE_KEY environment variable required');
    process.exit(1);
  }

  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  console.log(`Wallet: ${wallet.address}\n`);

  switch (command) {
    case 'create':
      const dailyLimit = process.argv[3] || '100';
      await createSmartAccount(wallet, dailyLimit);
      break;

    case 'fund':
      const accountAddress = process.argv[3];
      const amount = process.argv[4];
      if (!accountAddress || !amount) {
        console.error('Error: account_address and amount required');
        process.exit(1);
      }
      await fundSmartAccount(wallet, accountAddress, amount);
      break;
  }
}

main().catch(console.error);
