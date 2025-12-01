/**
 * NOVIS SDK TypeScript Definitions
 */

export interface Addresses {
  NOVIS_TOKEN: string;
  VAULT: string;
  STRATEGY: string;
  FACTORY: string;
  DEX_POOL: string;
  TREASURY: string;
  USDC: string;
  ENTRYPOINT: string;
  RELAYER_API: string;
  RPC_URL: string;
  CHAIN_ID: number;
}

export interface ClientOptions {
  rpcUrl?: string;
  relayerUrl?: string;
}

export interface TransferResult {
  success: boolean;
  txHash: string;
  blockNumber: number;
  from: string;
  to: string;
  amount: string;
  explorerUrl: string;
}

export interface DirectTransferResult {
  success: boolean;
  txHash: string;
  blockNumber: number;
  gasUsed: string;
  explorerUrl: string;
}

export interface FeeInfo {
  amount: string;
  amountWei: string;
  fee: string;
  feeWei: string;
  netAmount: string;
  netAmountWei: string;
  feePercent: string;
}

export interface ProtocolStats {
  totalSupply: string;
  totalAssets: string;
  backingRatioBps: number;
  backingRatioPercent: string;
  totalFeesCollected: string;
  totalMetaTxRelayed: number;
  feeThreshold: string;
  feePercentage: string;
}

export interface DepositResult {
  success: boolean;
  txHash: string;
  blockNumber: number;
  usdcDeposited: string;
  explorerUrl: string;
}

export interface RedeemResult {
  success: boolean;
  txHash: string;
  blockNumber: number;
  novisRedeemed: string;
  explorerUrl: string;
}

export declare const ADDRESSES: Addresses;

export declare class NOVISClient {
  constructor(privateKey: string, options?: ClientOptions);
  
  readonly address: string;
  
  // Balance & Info
  getBalance(address?: string): Promise<string>;
  getUSDCBalance(address?: string): Promise<string>;
  getETHBalance(address?: string): Promise<string>;
  getProtocolStats(): Promise<ProtocolStats>;
  
  // Gasless Transfer
  transfer(to: string, amount: string): Promise<TransferResult>;
  calculateFee(to: string, amount: string): Promise<FeeInfo>;
  
  // Direct Transfer
  transferDirect(to: string, amount: string): Promise<DirectTransferResult>;
  
  // Vault Operations
  deposit(amount: string): Promise<DepositResult>;
  redeem(amount: string): Promise<RedeemResult>;
  
  // Smart Accounts
  createSmartAccount(dailyLimit: string): Promise<string>;
  getMySmartAccounts(): Promise<string[]>;
  fundSmartAccount(accountAddress: string, amount: string): Promise<DirectTransferResult>;
}

// Utility Functions
export declare function formatNOVIS(wei: string | bigint): string;
export declare function parseNOVIS(amount: string): bigint;
export declare function formatUSDC(wei: string | bigint): string;
export declare function parseUSDC(amount: string): bigint;
export declare function isValidAddress(address: string): boolean;

export default NOVISClient;
