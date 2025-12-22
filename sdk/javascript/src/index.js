/**
 * NOVIS SDK
 * 
 * Gasless payments for AI agents on Base.
 * 
 * @example
 * import { NOVISClient } from '@novis/sdk';
 * 
 * const client = new NOVISClient({ privateKey: process.env.PRIVATE_KEY });
 * await client.transfer('0x...', '100');
 */

import { ethers } from 'ethers';

// Contract addresses (Base Mainnet)
export const ADDRESSES = {
  NOVIS_TOKEN: '0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85',
  VAULT: '0xA3D771bF986174D9cf9C85072cCD11cb72A694d4',
  PAYMENT_ROUTER: '0xc95D114A333d0394e562BD398c4787fd22d27110',
  GENESIS: '0xa23a81b1F7fB96DF6d12a579c2660b1ffbAAB2b7',
  SMART_ACCOUNTS: '0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA',
  USDC: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
};

// Network config
export const NETWORK = {
  chainId: 8453,
  name: 'Base',
  rpcUrl: 'https://mainnet.base.org'
};

// ABIs
const TOKEN_ABI = [
  'function balanceOf(address account) view returns (uint256)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function nonces(address owner) view returns (uint256)',
  'function metaTransferV2(address from, address to, uint256 amount, uint256 nonce, uint256 deadline, bytes signature) returns (bool)'
];

const ROUTER_ABI = [
  'function payWithMemo(address to, uint256 amount, string memo)',
  'function createEscrow(address to, uint256 amount, uint256 timeout) returns (uint256)',
  'function releaseEscrow(uint256 escrowId)',
  'function refundEscrow(uint256 escrowId)',
  'function getEscrow(uint256 escrowId) view returns (address payer, address payee, uint256 amount, uint256 deadline, bool released, bool refunded)',
  'function batchPay(address[] recipients, uint256[] amounts, string[] memos)',
  'event EscrowCreated(uint256 indexed escrowId, address indexed payer, address indexed payee, uint256 amount, uint256 deadline)',
  'event PaymentWithMemo(address indexed from, address indexed to, uint256 amount, string memo)'
];

const VAULT_ABI = [
  'function deposit(uint256 usdcAmount)',
  'function redeem(uint256 novisAmount)',
  'function totalBackingUSDC() view returns (uint256)'
];

const USDC_ABI = [
  'function balanceOf(address account) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)'
];

// EIP-712 Domain for meta-transactions
const EIP712_DOMAIN = {
  name: 'NOVIS',
  version: '1',
  chainId: NETWORK.chainId,
  verifyingContract: ADDRESSES.NOVIS_TOKEN
};

const META_TRANSFER_TYPES = {
  MetaTransfer: [
    { name: 'from', type: 'address' },
    { name: 'to', type: 'address' },
    { name: 'amount', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
  ]
};

/**
 * NOVIS Client
 * 
 * Main SDK class for interacting with NOVIS protocol.
 */
export class NOVISClient {
  /**
   * Create a new NOVIS client
   * 
   * @param {Object} options
   * @param {string} options.privateKey - Wallet private key
   * @param {string} [options.rpcUrl] - Custom RPC URL (default: Base mainnet)
   */
  constructor({ privateKey, rpcUrl = NETWORK.rpcUrl }) {
    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.wallet = new ethers.Wallet(privateKey, this.provider);
    
    // Contract instances
    this.token = new ethers.Contract(ADDRESSES.NOVIS_TOKEN, TOKEN_ABI, this.wallet);
    this.router = new ethers.Contract(ADDRESSES.PAYMENT_ROUTER, ROUTER_ABI, this.wallet);
    this.vault = new ethers.Contract(ADDRESSES.VAULT, VAULT_ABI, this.wallet);
    this.usdc = new ethers.Contract(ADDRESSES.USDC, USDC_ABI, this.wallet);
  }

  /**
   * Get wallet address
   * @returns {string}
   */
  get address() {
    return this.wallet.address;
  }

  // ============================================
  // BALANCE & INFO
  // ============================================

  /**
   * Get NOVIS balance
   * @param {string} [address] - Address to check (default: own wallet)
   * @returns {Promise<string>} Balance in NOVIS
   */
  async getBalance(address = this.wallet.address) {
    const balance = await this.token.balanceOf(address);
    return ethers.formatEther(balance);
  }

  /**
   * Get USDC balance
   * @param {string} [address] - Address to check (default: own wallet)
   * @returns {Promise<string>} Balance in USDC
   */
  async getUSDCBalance(address = this.wallet.address) {
    const balance = await this.usdc.balanceOf(address);
    return ethers.formatUnits(balance, 6);
  }

  /**
   * Get total USDC backing in vault
   * @returns {Promise<string>} Total backing in USDC
   */
  async getTotalBacking() {
    const backing = await this.vault.totalBackingUSDC();
    return ethers.formatUnits(backing, 6);
  }

  // ============================================
  // TRANSFERS
  // ============================================

  /**
   * Transfer NOVIS tokens
   * @param {string} to - Recipient address
   * @param {string} amount - Amount in NOVIS
   * @returns {Promise<Object>} Transaction receipt
   */
  async transfer(to, amount) {
    const amountWei = ethers.parseEther(amount);
    const tx = await this.token.transfer(to, amountWei);
    return tx.wait();
  }

  /**
   * Gasless transfer using meta-transaction
   * @param {string} to - Recipient address
   * @param {string} amount - Amount in NOVIS
   * @returns {Promise<Object>} Transaction receipt
   */
  async transferGasless(to, amount) {
    const amountWei = ethers.parseEther(amount);
    const nonce = await this.token.nonces(this.wallet.address);
    const deadline = Math.floor(Date.now() / 1000) + 3600;

    const value = {
      from: this.wallet.address,
      to: to,
      amount: amountWei,
      nonce: nonce,
      deadline: deadline
    };

    const signature = await this.wallet.signTypedData(
      EIP712_DOMAIN,
      META_TRANSFER_TYPES,
      value
    );

    const tx = await this.token.metaTransferV2(
      this.wallet.address,
      to,
      amountWei,
      nonce,
      deadline,
      signature
    );

    return tx.wait();
  }

  /**
   * Pay with memo (attach reference to payment)
   * @param {string} to - Recipient address
   * @param {string} amount - Amount in NOVIS
   * @param {string} memo - Payment reference/memo
   * @returns {Promise<Object>} Transaction receipt
   */
  async payWithMemo(to, amount, memo) {
    await this._ensureRouterAllowance(amount);
    const amountWei = ethers.parseEther(amount);
    const tx = await this.router.payWithMemo(to, amountWei, memo);
    return tx.wait();
  }

  /**
   * Batch pay multiple recipients
   * @param {Array<Object>} payments - Array of {to, amount, memo}
   * @returns {Promise<Object>} Transaction receipt
   */
  async batchPay(payments) {
    const totalAmount = payments.reduce(
      (sum, p) => sum + parseFloat(p.amount),
      0
    ).toString();
    
    await this._ensureRouterAllowance(totalAmount);

    const recipients = payments.map(p => p.to);
    const amounts = payments.map(p => ethers.parseEther(p.amount));
    const memos = payments.map(p => p.memo || '');

    const tx = await this.router.batchPay(recipients, amounts, memos);
    return tx.wait();
  }

  // ============================================
  // ESCROW
  // ============================================

  /**
   * Create escrow payment
   * @param {string} to - Payee address
   * @param {string} amount - Amount in NOVIS
   * @param {number} timeout - Timeout in seconds
   * @returns {Promise<Object>} {receipt, escrowId}
   */
  async createEscrow(to, amount, timeout = 3600) {
    await this._ensureRouterAllowance(amount);
    const amountWei = ethers.parseEther(amount);
    
    const tx = await this.router.createEscrow(to, amountWei, timeout);
    const receipt = await tx.wait();

    // Parse escrow ID from event
    let escrowId = null;
    for (const log of receipt.logs) {
      try {
        const parsed = this.router.interface.parseLog(log);
        if (parsed?.name === 'EscrowCreated') {
          escrowId = parsed.args.escrowId.toString();
          break;
        }
      } catch {}
    }

    return { receipt, escrowId };
  }

  /**
   * Release escrow (send funds to payee)
   * @param {string|number} escrowId
   * @returns {Promise<Object>} Transaction receipt
   */
  async releaseEscrow(escrowId) {
    const tx = await this.router.releaseEscrow(escrowId);
    return tx.wait();
  }

  /**
   * Refund escrow (return funds to payer)
   * @param {string|number} escrowId
   * @returns {Promise<Object>} Transaction receipt
   */
  async refundEscrow(escrowId) {
    const tx = await this.router.refundEscrow(escrowId);
    return tx.wait();
  }

  /**
   * Get escrow details
   * @param {string|number} escrowId
   * @returns {Promise<Object>} Escrow details
   */
  async getEscrow(escrowId) {
    const escrow = await this.router.getEscrow(escrowId);
    return {
      payer: escrow.payer,
      payee: escrow.payee,
      amount: ethers.formatEther(escrow.amount),
      deadline: new Date(Number(escrow.deadline) * 1000),
      released: escrow.released,
      refunded: escrow.refunded
    };
  }

  // ============================================
  // MINT / REDEEM
  // ============================================

  /**
   * Mint NOVIS by depositing USDC
   * @param {string} usdcAmount - Amount of USDC to deposit
   * @returns {Promise<Object>} Transaction receipt
   */
  async mint(usdcAmount) {
    const amountWei = ethers.parseUnits(usdcAmount, 6);
    
    // Approve USDC
    const allowance = await this.usdc.allowance(this.wallet.address, ADDRESSES.VAULT);
    if (allowance < amountWei) {
      const approveTx = await this.usdc.approve(ADDRESSES.VAULT, ethers.MaxUint256);
      await approveTx.wait();
    }

    const tx = await this.vault.deposit(amountWei);
    return tx.wait();
  }

  /**
   * Redeem NOVIS for USDC
   * @param {string} novisAmount - Amount of NOVIS to redeem
   * @returns {Promise<Object>} Transaction receipt
   */
  async redeem(novisAmount) {
    const amountWei = ethers.parseEther(novisAmount);
    const tx = await this.vault.redeem(amountWei);
    return tx.wait();
  }

  // ============================================
  // HELPERS
  // ============================================

  /**
   * Ensure router has sufficient allowance
   * @private
   */
  async _ensureRouterAllowance(amount) {
    const amountWei = ethers.parseEther(amount);
    const allowance = await this.token.allowance(
      this.wallet.address,
      ADDRESSES.PAYMENT_ROUTER
    );
    
    if (allowance < amountWei) {
      const tx = await this.token.approve(ADDRESSES.PAYMENT_ROUTER, ethers.MaxUint256);
      await tx.wait();
    }
  }

  /**
   * Listen for payment events
   * @param {Function} callback - Called with (from, to, amount, memo)
   */
  onPayment(callback) {
    this.router.on('PaymentWithMemo', (from, to, amount, memo) => {
      callback({
        from,
        to,
        amount: ethers.formatEther(amount),
        memo
      });
    });
  }

  /**
   * Listen for escrow events
   * @param {Function} callback - Called with escrow details
   */
  onEscrowCreated(callback) {
    this.router.on('EscrowCreated', (escrowId, payer, payee, amount, deadline) => {
      callback({
        escrowId: escrowId.toString(),
        payer,
        payee,
        amount: ethers.formatEther(amount),
        deadline: new Date(Number(deadline) * 1000)
      });
    });
  }
}

export default NOVISClient;
