/**
 * NOVIS SDK Example - Gasless Transfer
 * 
 * This example demonstrates how to send NOVIS without needing ETH for gas.
 * 
 * Usage:
 *   PRIVATE_KEY=0x... node gasless-transfer.js
 */

import { NOVISClient } from '../sdk/javascript/novis-sdk.js';

async function main() {
  // Check for private key
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error('Please set PRIVATE_KEY environment variable');
    process.exit(1);
  }

  // Initialize client
  const novis = new NOVISClient(privateKey);
  console.log('Wallet:', novis.address);

  // Check balance
  const balance = await novis.getBalance();
  console.log('NOVIS Balance:', balance);

  if (parseFloat(balance) < 1) {
    console.error('Insufficient NOVIS balance. Need at least 1 NOVIS.');
    process.exit(1);
  }

  // Recipient address (change this!)
  const recipient = '0x9503c0681b4f7bFDc8C39cC1954A458009987Cb9';
  const amount = '0.5'; // 0.5 NOVIS

  // Calculate fee first
  console.log('\n--- Fee Preview ---');
  const feeInfo = await novis.calculateFee(recipient, amount);
  console.log('Amount:', feeInfo.amount, 'NOVIS');
  console.log('Fee:', feeInfo.fee, 'NOVIS', `(${feeInfo.feePercent})`);
  console.log('Recipient gets:', feeInfo.netAmount, 'NOVIS');

  // Execute gasless transfer
  console.log('\n--- Executing Gasless Transfer ---');
  console.log('Signing and relaying...');
  
  try {
    const result = await novis.transfer(recipient, amount);
    
    console.log('\n✅ Transfer Successful!');
    console.log('Tx Hash:', result.txHash);
    console.log('Block:', result.blockNumber);
    console.log('View:', result.explorerUrl);
    
    // Check new balance
    const newBalance = await novis.getBalance();
    console.log('\nNew NOVIS Balance:', newBalance);
    
  } catch (error) {
    console.error('\n❌ Transfer Failed:', error.message);
    process.exit(1);
  }
}

main().catch(console.error);
