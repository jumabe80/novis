/**
 * NOVIS Batch Payment Example
 * 
 * Pay multiple recipients in a single transaction.
 * 
 * Usage:
 *   PRIVATE_KEY=0x... node batch-pay.js
 */

import { ethers } from 'ethers';

// Config
const NOVIS_TOKEN = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85';
const PAYMENT_ROUTER = '0xc95D114A333d0394e562BD398c4787fd22d27110';
const RPC_URL = 'https://mainnet.base.org';

// ABIs
const TOKEN_ABI = [
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)'
];

const ROUTER_ABI = [
  'function batchPay(address[] recipients, uint256[] amounts, string[] memos)',
  'event PaymentWithMemo(address indexed from, address indexed to, uint256 amount, string memo)'
];

async function main() {
  if (!process.env.PRIVATE_KEY) {
    console.error('Error: PRIVATE_KEY environment variable required');
    process.exit(1);
  }

  // Setup
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const token = new ethers.Contract(NOVIS_TOKEN, TOKEN_ABI, wallet);
  const router = new ethers.Contract(PAYMENT_ROUTER, ROUTER_ABI, wallet);

  console.log('='.repeat(50));
  console.log('NOVIS Batch Payment');
  console.log('='.repeat(50));
  console.log(`Wallet: ${wallet.address}`);

  // Check balance
  const balance = await token.balanceOf(wallet.address);
  console.log(`Balance: ${ethers.formatEther(balance)} NOVIS`);

  // Example payments (replace with your own)
  const payments = [
    {
      to: '0x1111111111111111111111111111111111111111',
      amount: '1',
      memo: 'task:research_topic_001'
    },
    {
      to: '0x2222222222222222222222222222222222222222',
      amount: '2',
      memo: 'task:write_summary_002'
    },
    {
      to: '0x3333333333333333333333333333333333333333',
      amount: '1.5',
      memo: 'task:review_content_003'
    }
  ];

  // Calculate total
  const total = payments.reduce((sum, p) => sum + parseFloat(p.amount), 0);
  console.log(`\nPayments to send:`);
  payments.forEach((p, i) => {
    console.log(`  ${i + 1}. ${p.to.slice(0, 10)}... → ${p.amount} NOVIS (${p.memo})`);
  });
  console.log(`  Total: ${total} NOVIS`);

  // Check if we have enough
  if (parseFloat(ethers.formatEther(balance)) < total) {
    console.error('\nError: Insufficient balance');
    process.exit(1);
  }

  // Approve router
  const allowance = await token.allowance(wallet.address, PAYMENT_ROUTER);
  const totalWei = ethers.parseEther(total.toString());
  
  if (allowance < totalWei) {
    console.log('\nApproving router...');
    const approveTx = await token.approve(PAYMENT_ROUTER, ethers.MaxUint256);
    await approveTx.wait();
    console.log('Approved!');
  }

  // Execute batch payment
  console.log('\nSending batch payment...');
  
  const recipients = payments.map(p => p.to);
  const amounts = payments.map(p => ethers.parseEther(p.amount));
  const memos = payments.map(p => p.memo);

  const tx = await router.batchPay(recipients, amounts, memos);
  console.log(`TX Hash: ${tx.hash}`);

  const receipt = await tx.wait();
  console.log(`\n✅ Batch payment successful!`);
  console.log(`Block: ${receipt.blockNumber}`);
  console.log(`Gas used: ${receipt.gasUsed}`);

  // Parse events
  console.log(`\nPayments made:`);
  for (const log of receipt.logs) {
    try {
      const parsed = router.interface.parseLog(log);
      if (parsed?.name === 'PaymentWithMemo') {
        console.log(`  → ${parsed.args.to.slice(0, 10)}...: ${ethers.formatEther(parsed.args.amount)} NOVIS`);
      }
    } catch {}
  }

  // Check new balance
  const newBalance = await token.balanceOf(wallet.address);
  console.log(`\nNew balance: ${ethers.formatEther(newBalance)} NOVIS`);
}

main().catch(console.error);
