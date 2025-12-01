/**
 * NOVIS SDK Example - AI Agent Setup
 * 
 * This example demonstrates how to create a smart account for an AI agent
 * with spending limits.
 * 
 * Usage:
 *   PRIVATE_KEY=0x... node ai-agent-setup.js
 */

import { NOVISClient, ADDRESSES } from '../sdk/javascript/novis-sdk.js';

async function main() {
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error('Please set PRIVATE_KEY environment variable');
    process.exit(1);
  }

  const novis = new NOVISClient(privateKey);
  console.log('Owner Wallet:', novis.address);

  // Check existing smart accounts
  console.log('\n--- Checking Existing Smart Accounts ---');
  const existingAccounts = await novis.getMySmartAccounts();
  console.log('Existing accounts:', existingAccounts.length);
  existingAccounts.forEach((acc, i) => {
    console.log(`  ${i + 1}. ${acc}`);
  });

  // Create new smart account
  console.log('\n--- Creating New Smart Account ---');
  console.log('Daily limit: 100 NOVIS');
  console.log('This requires ETH for the creation transaction...');
  
  try {
    const ethBalance = await novis.getETHBalance();
    if (parseFloat(ethBalance) < 0.001) {
      console.error('Need at least 0.001 ETH to create smart account');
      process.exit(1);
    }

    const accountAddress = await novis.createSmartAccount('100');
    
    console.log('\n✅ Smart Account Created!');
    console.log('Address:', accountAddress);
    console.log('View:', `https://basescan.org/address/${accountAddress}`);

    // Fund the smart account
    console.log('\n--- Funding Smart Account ---');
    const fundAmount = '10'; // 10 NOVIS
    
    const novisBalance = await novis.getBalance();
    if (parseFloat(novisBalance) < parseFloat(fundAmount)) {
      console.log('Not enough NOVIS to fund. Skipping...');
    } else {
      console.log(`Sending ${fundAmount} NOVIS to smart account...`);
      const fundResult = await novis.fundSmartAccount(accountAddress, fundAmount);
      console.log('Funded! Tx:', fundResult.txHash);
    }

    // Summary
    console.log('\n=== AI AGENT SETUP COMPLETE ===');
    console.log('Smart Account:', accountAddress);
    console.log('Daily Limit: 100 NOVIS');
    console.log('Owner:', novis.address);
    console.log('\nYour AI agent can now use this account for gasless transactions!');
    console.log('Use Pimlico for ERC-4337 bundler services.');

  } catch (error) {
    console.error('\n❌ Failed:', error.message);
    process.exit(1);
  }
}

main().catch(console.error);
