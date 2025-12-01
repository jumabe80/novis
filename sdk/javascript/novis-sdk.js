/**
 * NOVIS SDK for JavaScript/TypeScript
 * 
 * Gasless transactions for humans and AI agents on Base.
 * 
 * @version 1.0.0
 * @license MIT
 */

import { ethers } from 'ethers';

// =============================================================================
// CONSTANTS
// =============================================================================

export const ADDRESSES = {
  NOVIS_TOKEN: "0x1fb5e1C0c3DEc8da595E531b31C7B30c540E6B85",
  VAULT: "0xA3D771bF986174D9cf9C85072cCD11cb72A694d4",
  STRATEGY: "0x064E4586b7C63777BDC98A4776D3f78A93C0B752",
  FACTORY: "0x4b84E3a0D640c9139426f55204Fb34dB9B1123EA",
  DEX_POOL: "0xA0af1C990433102EFb08D78E060Ab05E6874ca69",
  TREASURY: "0x4709280aef7A496EA84e72dB3CAbAd5e324d593e",
  USDC: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  ENTRYPOINT: "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
  RELAYER_API: "https://novis-relayer-production.up.railway.app",
  RPC_URL: "https://mainnet.base.org",
  CHAIN_ID: 8453
};

const NOVIS_ABI = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function allowance(address,address) view returns (uint256)",
  "function transfer(address,uint256) returns (bool)",
  "function approve(address,uint256) returns (bool)",
  "function transferFrom(address,address,uint256) returns (bool)",
  "function feeThreshold() view returns (uint256)",
  "function feePercentageBps() view returns (uint16)",
  "function feesEnabled() view returns (bool)",
  "function calculateTransferFee(address,address,uint256) view returns (uint256,uint256)",
  "function getMetaTxNonce(address) view returns (uint256)",
  "function metaTransfer(address,address,uint256,uint256,bytes) returns (bool)",
  "function totalFeesCollected() view returns (uint256)",
  "function totalMetaTxRelayed() view returns (uint256)"
];

const VAULT_ABI = [
  "function deposit(uint256) returns (uint256)",
  "function redeem(uint256) returns (uint256)",
  "function totalAssets() view returns (uint256)",
  "function backingRatioBps() view returns (uint256)",
  "function paused() view returns (bool)"
];

const FACTORY_ABI = [
  "function createAccount(address,uint256,bytes32) returns (address)",
  "function accountCount() view returns (uint256)",
  "function accounts(uint256) view returns (address)",
  "function isAccount(address) view returns (bool)",
  "function getAccountsByOwner(address) view returns (address[])"
];

const USDC_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function approve(address,uint256) returns (bool)",
  "function allowance(address,address) view returns (uint256)"
];

// =============================================================================
// NOVIS CLIENT
// =============================================================================

export class NOVISClient {
  /**
   * Create a new NOVIS client
   * @param {string} privateKey - Wallet private key
   * @param {object} options - Optional configuration
   */
  constructor(privateKey, options = {}) {
    this.rpcUrl = options.rpcUrl || ADDRESSES.RPC_URL;
    this.relayerUrl = options.relayerUrl || ADDRESSES.RELAYER_API;
    
    this.provider = new ethers.JsonRpcProvider(this.rpcUrl);
    this.wallet = new ethers.Wallet(privateKey, this.provider);
    
    this.novis = new ethers.Contract(ADDRESSES.NOVIS_TOKEN, NOVIS_ABI, this.wallet);
    this.vault = new ethers.Contract(ADDRESSES.VAULT, VAULT_ABI, this.wallet);
    this.factory = new ethers.Contract(ADDRESSES.FACTORY, FACTORY_ABI, this.wallet);
    this.usdc = new ethers.Contract(ADDRESSES.USDC, USDC_ABI, this.wallet);
  }

  /**
   * Get wallet address
   * @returns {string} Address
   */
  get address() {
    return this.wallet.address;
  }

  // ===========================================================================
  // BALANCE & INFO
  // ===========================================================================

  /**
   * Get NOVIS balance
   * @param {string} address - Address to check (defaults to wallet)
   * @returns {Promise<string>} Balance in NOVIS (human readable)
   */
  async getBalance(address = null) {
    const addr = address || this.wallet.address;
    const balance = await this.novis.balanceOf(addr);
    return ethers.formatEther(balance);
  }

  /**
   * Get USDC balance
   * @param {string} address - Address to check (defaults to wallet)
   * @returns {Promise<string>} Balance in USDC (human readable, 6 decimals)
   */
  async getUSDCBalance(address = null) {
    const addr = address || this.wallet.address;
    const balance = await this.usdc.balanceOf(addr);
    return ethers.formatUnits(balance, 6);
  }

  /**
   * Get ETH balance
   * @param {string} address - Address to check (defaults to wallet)
   * @returns {Promise<string>} Balance in ETH
   */
  async getETHBalance(address = null) {
    const addr = address || this.wallet.address;
    const balance = await this.provider.getBalance(addr);
    return ethers.formatEther(balance);
  }

  /**
   * Get protocol stats
   * @returns {Promise<object>} Protocol statistics
   */
  async getProtocolStats() {
    const [
      totalSupply,
      totalAssets,
      backingRatio,
      totalFees,
      totalMetaTx,
      feeThreshold,
      feeBps
    ] = await Promise.all([
      this.novis.totalSupply(),
      this.vault.totalAssets(),
      this.vault.backingRatioBps(),
      this.novis.totalFeesCollected(),
      this.novis.totalMetaTxRelayed(),
      this.novis.feeThreshold(),
      this.novis.feePercentageBps()
    ]);

    return {
      totalSupply: ethers.formatEther(totalSupply),
      totalAssets: ethers.formatUnits(totalAssets, 6),
      backingRatioBps: Number(backingRatio),
      backingRatioPercent: (Number(backingRatio) / 100).toFixed(2) + '%',
      totalFeesCollected: ethers.formatEther(totalFees),
      totalMetaTxRelayed: Number(totalMetaTx),
      feeThreshold: ethers.formatEther(feeThreshold),
      feePercentage: (Number(feeBps) / 100).toFixed(2) + '%'
    };
  }

  // ===========================================================================
  // GASLESS TRANSFER (META-TRANSACTION)
  // ===========================================================================

  /**
   * Send NOVIS gaslessly via meta-transaction
   * @param {string} to - Recipient address
   * @param {string} amount - Amount in NOVIS (e.g., "10.0")
   * @returns {Promise<object>} Transaction result
   */
  async transfer(to, amount) {
    const amountWei = ethers.parseEther(amount);
    
    // 1. Get nonce
    const nonceRes = await fetch(`${this.relayerUrl}/nonce/${this.wallet.address}`);
    if (!nonceRes.ok) throw new Error('Failed to get nonce');
    const { nonce } = await nonceRes.json();
    
    // 2. Get domain
    const domainRes = await fetch(`${this.relayerUrl}/domain`);
    if (!domainRes.ok) throw new Error('Failed to get domain');
    const domainData = await domainRes.json();
    
    // 3. Build message
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    
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
      from: this.wallet.address,
      to: to,
      amount: amountWei,
      nonce: BigInt(nonce),
      deadline: BigInt(deadline)
    };
    
    // 4. Sign
    const signature = await this.wallet.signTypedData(domain, types, message);
    
    // 5. Relay
    const relayRes = await fetch(`${this.relayerUrl}/relay`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: this.wallet.address,
        to: to,
        amount: amountWei.toString(),
        deadline: deadline.toString(),
        signature: signature
      })
    });
    
    const result = await relayRes.json();
    
    if (!result.success) {
      throw new Error(result.error || 'Relay failed');
    }
    
    return {
      success: true,
      txHash: result.txHash,
      blockNumber: result.blockNumber,
      from: this.wallet.address,
      to: to,
      amount: amount,
      explorerUrl: `https://basescan.org/tx/${result.txHash}`
    };
  }

  /**
   * Calculate fee for a transfer
   * @param {string} to - Recipient address
   * @param {string} amount - Amount in NOVIS
   * @returns {Promise<object>} Fee information
   */
  async calculateFee(to, amount) {
    const amountWei = ethers.parseEther(amount);
    const [fee, netAmount] = await this.novis.calculateTransferFee(
      this.wallet.address,
      to,
      amountWei
    );
    
    return {
      amount: amount,
      amountWei: amountWei.toString(),
      fee: ethers.formatEther(fee),
      feeWei: fee.toString(),
      netAmount: ethers.formatEther(netAmount),
      netAmountWei: netAmount.toString(),
      feePercent: fee > 0n ? '0.1%' : '0%'
    };
  }

  // ===========================================================================
  // DIRECT TRANSFER (Requires ETH for gas)
  // ===========================================================================

  /**
   * Send NOVIS directly (requires ETH for gas)
   * @param {string} to - Recipient address
   * @param {string} amount - Amount in NOVIS
   * @returns {Promise<object>} Transaction result
   */
  async transferDirect(to, amount) {
    const amountWei = ethers.parseEther(amount);
    const tx = await this.novis.transfer(to, amountWei);
    const receipt = await tx.wait();
    
    return {
      success: receipt.status === 1,
      txHash: receipt.hash,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toString(),
      explorerUrl: `https://basescan.org/tx/${receipt.hash}`
    };
  }

  // ===========================================================================
  // VAULT OPERATIONS
  // ===========================================================================

  /**
   * Deposit USDC to get NOVIS
   * @param {string} amount - Amount in USDC (e.g., "100")
   * @returns {Promise<object>} Transaction result
   */
  async deposit(amount) {
    const amountWei = ethers.parseUnits(amount, 6);
    
    // Check allowance
    const allowance = await this.usdc.allowance(this.wallet.address, ADDRESSES.VAULT);
    if (allowance < amountWei) {
      const approveTx = await this.usdc.approve(ADDRESSES.VAULT, amountWei);
      await approveTx.wait();
    }
    
    // Deposit
    const tx = await this.vault.deposit(amountWei);
    const receipt = await tx.wait();
    
    return {
      success: receipt.status === 1,
      txHash: receipt.hash,
      blockNumber: receipt.blockNumber,
      usdcDeposited: amount,
      explorerUrl: `https://basescan.org/tx/${receipt.hash}`
    };
  }

  /**
   * Redeem NOVIS for USDC
   * @param {string} amount - Amount in NOVIS (e.g., "100")
   * @returns {Promise<object>} Transaction result
   */
  async redeem(amount) {
    const amountWei = ethers.parseEther(amount);
    const tx = await this.vault.redeem(amountWei);
    const receipt = await tx.wait();
    
    return {
      success: receipt.status === 1,
      txHash: receipt.hash,
      blockNumber: receipt.blockNumber,
      novisRedeemed: amount,
      explorerUrl: `https://basescan.org/tx/${receipt.hash}`
    };
  }

  // ===========================================================================
  // SMART ACCOUNTS (For AI Agents)
  // ===========================================================================

  /**
   * Create a smart account for AI agent
   * @param {string} dailyLimit - Daily spending limit in NOVIS
   * @returns {Promise<string>} Smart account address
   */
  async createSmartAccount(dailyLimit) {
    const dailyLimitWei = ethers.parseEther(dailyLimit);
    const salt = ethers.keccak256(
      ethers.toUtf8Bytes(Date.now().toString() + Math.random())
    );
    
    const tx = await this.factory.createAccount(
      this.wallet.address,
      dailyLimitWei,
      salt
    );
    await tx.wait();
    
    // Get account address
    const count = await this.factory.accountCount();
    const accountAddress = await this.factory.accounts(count - 1n);
    
    return accountAddress;
  }

  /**
   * Get all smart accounts owned by this wallet
   * @returns {Promise<string[]>} Array of account addresses
   */
  async getMySmartAccounts() {
    return await this.factory.getAccountsByOwner(this.wallet.address);
  }

  /**
   * Fund a smart account with NOVIS
   * @param {string} accountAddress - Smart account address
   * @param {string} amount - Amount in NOVIS
   * @returns {Promise<object>} Transaction result
   */
  async fundSmartAccount(accountAddress, amount) {
    return await this.transferDirect(accountAddress, amount);
  }
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Format NOVIS amount for display
 * @param {string|bigint} wei - Amount in wei
 * @returns {string} Formatted amount
 */
export function formatNOVIS(wei) {
  return ethers.formatEther(wei);
}

/**
 * Parse NOVIS amount from string
 * @param {string} amount - Amount in NOVIS
 * @returns {bigint} Amount in wei
 */
export function parseNOVIS(amount) {
  return ethers.parseEther(amount);
}

/**
 * Format USDC amount for display
 * @param {string|bigint} wei - Amount in wei (6 decimals)
 * @returns {string} Formatted amount
 */
export function formatUSDC(wei) {
  return ethers.formatUnits(wei, 6);
}

/**
 * Parse USDC amount from string
 * @param {string} amount - Amount in USDC
 * @returns {bigint} Amount in wei
 */
export function parseUSDC(amount) {
  return ethers.parseUnits(amount, 6);
}

/**
 * Check if an address is valid
 * @param {string} address - Ethereum address
 * @returns {boolean} True if valid
 */
export function isValidAddress(address) {
  return ethers.isAddress(address);
}

// =============================================================================
// DEFAULT EXPORT
// =============================================================================

export default NOVISClient;
