/**
 * NOVIS Escrow Example
 * 
 * Create and manage escrow payments for AI agent tasks.
 * 
 * Usage:
 *   PRIVATE_KEY=0x... node escrow.js create <recipient> <amount> <timeout_seconds>
 *   PRIVATE_KEY=0x... node escrow.js release <escrow_id>
 *   PRIVATE_KEY=0x... node escrow.js refund <escrow_id>
 *   PRIVATE_KEY=0x... node escrow.js status <escrow_id>
 */

import { ethers } from 'ethers';

// Config
const NOVIS_TOKEN = '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85';
const PAYMENT_ROUTER = '0xc95D114A333d0394e562BD398c4787fd22d27110';
const RPC_URL = 'https://mainnet.base.org';

// ABIs
const TOKEN_ABI = [
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)'
];

const ROUTER_ABI = [
  'function createEscrow(address to, uint256 amount, uint256 timeout) returns (uint256)',
  'function releaseEscrow(uint256 escrowId)',
  'function refundEscrow(uint256 escrowId)',
  'function getEscrow(uint256 escrowId) view returns (address payer, address payee, uint256 amount, uint256 deadline, bool released, bool refunded)',
  'event EscrowCreated(uint256 indexed escrowId, address indexed payer, address indexed payee, uint256 amount, uint256 deadline)'
];

async function createEscrow(wallet, recipient, amount, timeout) {
  const provider = wallet.provider;
  const token = new ethers.Contract(NOVIS_TOKEN, TOKEN_ABI, wallet);
  const router = new ethers.Contract(PAYMENT_ROUTER, ROUTER_ABI, wallet);

  const amountWei = ethers.parseEther(amount);

  // Check and set allowance
  const allowance = await token.allowance(wallet.address, PAYMENT_ROUTER);
  if (allowance < amountWei) {
    console.log('Approving router to spend NOVIS...');
    const approveTx = await token.approve(PAYMENT_ROUTER, ethers.MaxUint256);
    await approveTx.wait();
    console.log('Approved!');
  }

  // Create escrow
  console.log(`\nCreating escrow...`);
  console.log(`  Recipient: ${recipient}`);
  console.log(`  Amount: ${amount} NOVIS`);
  console.log(`  Timeout: ${timeout} seconds`);

  const tx = await router.createEscrow(recipient, amountWei, timeout);
  console.log(`TX Hash: ${tx.hash}`);

  const receipt = await tx.wait();
  
  // Parse escrow ID from event
  const event = receipt.logs.find(log => {
    try {
      return router.interface.parseLog(log)?.name === 'EscrowCreated';
    } catch { return false; }
  });

  if (event) {
    const parsed = router.interface.parseLog(event);
    console.log(`\n✅ Escrow created!`);
    console.log(`   Escrow ID: ${parsed.args.escrowId}`);
    console.log(`   Deadline: ${new Date(Number(parsed.args.deadline) * 1000).toISOString()}`);
  }
}

async function releaseEscrow(wallet, escrowId) {
  const router = new ethers.Contract(PAYMENT_ROUTER, ROUTER_ABI, wallet);

  console.log(`Releasing escrow #${escrowId}...`);
  const tx = await router.releaseEscrow(escrowId);
  console.log(`TX Hash: ${tx.hash}`);

  await tx.wait();
  console.log(`\n✅ Escrow released! Funds sent to payee.`);
}

async function refundEscrow(wallet, escrowId) {
  const router = new ethers.Contract(PAYMENT_ROUTER, ROUTER_ABI, wallet);

  console.log(`Refunding escrow #${escrowId}...`);
  const tx = await router.refundEscrow(escrowId);
  console.log(`TX Hash: ${tx.hash}`);

  await tx.wait();
  console.log(`\n✅ Escrow refunded! Funds returned to payer.`);
}

async function getEscrowStatus(provider, escrowId) {
  const router = new ethers.Contract(PAYMENT_ROUTER, ROUTER_ABI, provider);

  console.log(`\nEscrow #${escrowId} Status:`);
  console.log('='.repeat(40));

  const escrow = await router.getEscrow(escrowId);
  
  console.log(`Payer:    ${escrow.payer}`);
  console.log(`Payee:    ${escrow.payee}`);
  console.log(`Amount:   ${ethers.formatEther(escrow.amount)} NOVIS`);
  console.log(`Deadline: ${new Date(Number(escrow.deadline) * 1000).toISOString()}`);
  console.log(`Released: ${escrow.released}`);
  console.log(`Refunded: ${escrow.refunded}`);

  const now = Math.floor(Date.now() / 1000);
  if (!escrow.released && !escrow.refunded) {
    if (now < Number(escrow.deadline)) {
      console.log(`\nStatus: ⏳ PENDING (${Math.floor((Number(escrow.deadline) - now) / 60)} minutes remaining)`);
    } else {
      console.log(`\nStatus: ⚠️ EXPIRED (can be refunded)`);
    }
  } else if (escrow.released) {
    console.log(`\nStatus: ✅ RELEASED`);
  } else {
    console.log(`\nStatus: ↩️ REFUNDED`);
  }
}

async function main() {
  const command = process.argv[2];

  if (!command || !['create', 'release', 'refund', 'status'].includes(command)) {
    console.log('NOVIS Escrow Manager');
    console.log('='.repeat(40));
    console.log('Usage:');
    console.log('  node escrow.js create <recipient> <amount> <timeout>');
    console.log('  node escrow.js release <escrow_id>');
    console.log('  node escrow.js refund <escrow_id>');
    console.log('  node escrow.js status <escrow_id>');
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(RPC_URL);

  if (command === 'status') {
    const escrowId = process.argv[3];
    if (!escrowId) {
      console.error('Error: escrow_id required');
      process.exit(1);
    }
    await getEscrowStatus(provider, escrowId);
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
      const recipient = process.argv[3];
      const amount = process.argv[4];
      const timeout = process.argv[5] || '3600';
      if (!recipient || !amount) {
        console.error('Error: recipient and amount required');
        process.exit(1);
      }
      await createEscrow(wallet, recipient, amount, timeout);
      break;

    case 'release':
      const releaseId = process.argv[3];
      if (!releaseId) {
        console.error('Error: escrow_id required');
        process.exit(1);
      }
      await releaseEscrow(wallet, releaseId);
      break;

    case 'refund':
      const refundId = process.argv[3];
      if (!refundId) {
        console.error('Error: escrow_id required');
        process.exit(1);
      }
      await refundEscrow(wallet, refundId);
      break;
  }
}

main().catch(console.error);
