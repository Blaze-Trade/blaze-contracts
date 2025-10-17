/**
 * Blaze Launchpad V2 SDK
 * 
 * Simple SDK for frontend integration with Blaze Launchpad V2
 * 
 * @example
 * ```typescript
 * import { createPool, buyTokens, sellTokens } from './blaze-sdk';
 * 
 * // Create a pool
 * const poolTx = await createPool(account, {
 *   name: "My Token",
 *   ticker: "MTK",
 *   imageUri: "https://example.com/logo.png",
 *   decimals: 8,
 *   reserveRatio: 50,
 *   initialReserveApt: 0.1
 * });
 * 
 * // Buy tokens
 * const buyTx = await buyTokens(account, poolId, 0.1);
 * 
 * // Sell tokens
 * const sellTx = await sellTokens(account, poolId, 100);
 * ```
 */

import { 
  Aptos, 
  AptosConfig, 
  Network, 
  Account,
  AccountAddress
} from "@aptos-labs/ts-sdk";

// ============================================================================
// CONSTANTS
// ============================================================================

/** Blaze Launchpad V2 contract address on testnet */
export const CONTRACT_ADDRESS = "0xf2ca7e5f4e8fb07ea86f701ca1fd1da98d5c41d2f87979be0723a13da3bca125";

/** Default network configuration */
export const NETWORK = Network.TESTNET;

// ============================================================================
// TYPES
// ============================================================================

export interface CreatePoolParams {
  /** Token name (e.g., "My Token") */
  name: string;
  
  /** Token ticker symbol, 1-10 characters (e.g., "MTK") */
  ticker: string;
  
  /** Token image URI */
  imageUri: string;
  
  /** Token description (optional) */
  description?: string;
  
  /** Website URL (optional) */
  website?: string;
  
  /** Twitter handle (optional) */
  twitter?: string;
  
  /** Telegram link (optional) */
  telegram?: string;
  
  /** Discord link (optional) */
  discord?: string;
  
  /** Maximum token supply (optional, undefined = unlimited) */
  maxSupply?: bigint;
  
  /** Number of decimals (default: 8) */
  decimals?: number;
  
  /** Reserve ratio percentage 1-100 (default: 50) */
  reserveRatio?: number;
  
  /** Initial APT reserve amount in APT (e.g., 1 for 1 APT) */
  initialReserveApt: number;
  
  /** Market cap threshold in USD (optional) */
  thresholdUsd?: number;
}

export interface TransactionResult {
  /** Transaction hash */
  hash: string;
  
  /** Explorer URL */
  explorerUrl: string;
  
  /** Success status */
  success: boolean;
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Get Aptos client instance
 */
export function getAptosClient(network: Network = NETWORK): Aptos {
  const config = new AptosConfig({ network });
  return new Aptos(config);
}

/**
 * Get explorer URL for a transaction
 */
export function getExplorerUrl(txHash: string, network: Network = NETWORK): string {
  const networkName = network === Network.TESTNET ? "testnet" : 
                      network === Network.MAINNET ? "mainnet" : "devnet";
  return `https://explorer.aptoslabs.com/txn/${txHash}?network=${networkName}`;
}

/**
 * Convert APT to octas (1 APT = 100,000,000 octas)
 */
export function aptToOctas(apt: number): number {
  return Math.floor(apt * 100_000_000);
}

/**
 * Convert octas to APT
 */
export function octasToApt(octas: number): number {
  return octas / 100_000_000;
}

/**
 * Convert tokens to base units (with decimals)
 */
export function tokensToBaseUnits(tokens: number, decimals: number = 8): number {
  return Math.floor(tokens * Math.pow(10, decimals));
}

/**
 * Convert base units to tokens
 */
export function baseUnitsToTokens(baseUnits: number, decimals: number = 8): number {
  return baseUnits / Math.pow(10, decimals);
}

// ============================================================================
// MAIN FUNCTIONS
// ============================================================================

/**
 * Create a new token pool
 * 
 * @param account - Signer account
 * @param params - Pool creation parameters
 * @param network - Network to use (default: TESTNET)
 * @returns Transaction result
 * 
 * @example
 * ```typescript
 * const result = await createPool(account, {
 *   name: "My Token",
 *   ticker: "MTK",
 *   imageUri: "https://example.com/logo.png",
 *   description: "An amazing token",
 *   decimals: 8,
 *   reserveRatio: 50,
 *   initialReserveApt: 0.1,
 *   thresholdUsd: 75000
 * });
 * 
 * console.log(`Pool created! Tx: ${result.hash}`);
 * ```
 */
export async function createPool(
  account: Account,
  params: CreatePoolParams,
  network: Network = NETWORK
): Promise<TransactionResult> {
  const aptos = getAptosClient(network);
  
  // Validate parameters
  if (!params.name || params.name.trim().length === 0) {
    throw new Error("Token name is required");
  }
  if (!params.ticker || params.ticker.length < 1 || params.ticker.length > 10) {
    throw new Error("Token ticker must be 1-10 characters");
  }
  if (!params.imageUri) {
    throw new Error("Image URI is required");
  }
  if (params.reserveRatio && (params.reserveRatio < 1 || params.reserveRatio > 100)) {
    throw new Error("Reserve ratio must be between 1 and 100");
  }
  
  // Set defaults
  const decimals = params.decimals ?? 8;
  const reserveRatio = params.reserveRatio ?? 50;
  const initialReserveOctas = aptToOctas(params.initialReserveApt);
  
  // Build function arguments
  const functionArguments = [
    params.name,
    params.ticker,
    params.imageUri,
    params.description || undefined,
    params.website || undefined,
    params.twitter || undefined,
    params.telegram || undefined,
    params.discord || undefined,
    params.maxSupply || undefined,
    decimals,
    reserveRatio,
    initialReserveOctas,
    params.thresholdUsd ? params.thresholdUsd * 100 : undefined // Convert to cents
  ];
  
  // Build and submit transaction
  const transaction = await aptos.transaction.build.simple({
    sender: account.accountAddress,
    data: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::create_pool`,
      functionArguments,
    },
  });
  
  const committedTxn = await aptos.signAndSubmitTransaction({
    signer: account,
    transaction,
  });
  
  // Wait for confirmation
  await aptos.waitForTransaction({ 
    transactionHash: committedTxn.hash 
  });
  
  return {
    hash: committedTxn.hash,
    explorerUrl: getExplorerUrl(committedTxn.hash, network),
    success: true
  };
}

/**
 * Buy tokens from a pool using APT
 * 
 * @param account - Signer account
 * @param poolId - Pool object address
 * @param aptAmount - Amount of APT to spend
 * @param minTokensOut - Minimum tokens to receive (slippage protection, default: 0)
 * @param deadlineMinutes - Transaction deadline in minutes from now (default: 5)
 * @param network - Network to use (default: TESTNET)
 * @returns Transaction result
 * 
 * @example
 * ```typescript
 * const result = await buyTokens(
 *   account,
 *   "0x1234...",
 *   0.1,  // Buy with 0.1 APT
 *   0,    // No slippage protection
 *   5     // 5 minute deadline
 * );
 * 
 * console.log(`Tokens purchased! Tx: ${result.hash}`);
 * ```
 */
export async function buyTokens(
  account: Account,
  poolId: string,
  aptAmount: number,
  minTokensOut: number = 0,
  deadlineMinutes: number = 5,
  network: Network = NETWORK
): Promise<TransactionResult> {
  const aptos = getAptosClient(network);
  
  if (aptAmount <= 0) {
    throw new Error("APT amount must be greater than 0");
  }
  
  const aptAmountOctas = aptToOctas(aptAmount);
  const deadline = Math.floor(Date.now() / 1000) + (deadlineMinutes * 60);
  
  const transaction = await aptos.transaction.build.simple({
    sender: account.accountAddress,
    data: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::buy`,
      functionArguments: [
        poolId,
        aptAmountOctas,
        minTokensOut,
        deadline
      ],
    },
  });
  
  const committedTxn = await aptos.signAndSubmitTransaction({
    signer: account,
    transaction,
  });
  
  await aptos.waitForTransaction({ 
    transactionHash: committedTxn.hash 
  });
  
  return {
    hash: committedTxn.hash,
    explorerUrl: getExplorerUrl(committedTxn.hash, network),
    success: true
  };
}

/**
 * Sell tokens to a pool for APT
 * 
 * @param account - Signer account
 * @param poolId - Pool object address
 * @param tokenAmount - Amount of tokens to sell (in token units, not base units)
 * @param minAptOut - Minimum APT to receive (slippage protection, default: 0)
 * @param decimals - Token decimals (default: 8)
 * @param deadlineMinutes - Transaction deadline in minutes from now (default: 5)
 * @param network - Network to use (default: TESTNET)
 * @returns Transaction result
 * 
 * @example
 * ```typescript
 * const result = await sellTokens(
 *   account,
 *   "0x1234...",
 *   100,  // Sell 100 tokens
 *   0,    // No slippage protection
 *   8,    // 8 decimals
 *   5     // 5 minute deadline
 * );
 * 
 * console.log(`Tokens sold! Tx: ${result.hash}`);
 * ```
 */
export async function sellTokens(
  account: Account,
  poolId: string,
  tokenAmount: number,
  minAptOut: number = 0,
  decimals: number = 8,
  deadlineMinutes: number = 5,
  network: Network = NETWORK
): Promise<TransactionResult> {
  const aptos = getAptosClient(network);
  
  if (tokenAmount <= 0) {
    throw new Error("Token amount must be greater than 0");
  }
  
  const tokenAmountBase = tokensToBaseUnits(tokenAmount, decimals);
  const minAptOutOctas = aptToOctas(minAptOut);
  const deadline = Math.floor(Date.now() / 1000) + (deadlineMinutes * 60);
  
  const transaction = await aptos.transaction.build.simple({
    sender: account.accountAddress,
    data: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::sell`,
      functionArguments: [
        poolId,
        tokenAmountBase,
        minAptOutOctas,
        deadline
      ],
    },
  });
  
  const committedTxn = await aptos.signAndSubmitTransaction({
    signer: account,
    transaction,
  });
  
  await aptos.waitForTransaction({ 
    transactionHash: committedTxn.hash 
  });
  
  return {
    hash: committedTxn.hash,
    explorerUrl: getExplorerUrl(committedTxn.hash, network),
    success: true
  };
}

// ============================================================================
// VIEW FUNCTIONS
// ============================================================================

/**
 * Get all pool IDs
 * 
 * @param network - Network to use (default: TESTNET)
 * @returns Array of pool addresses
 * 
 * @example
 * ```typescript
 * const pools = await getPools();
 * console.log(`Found ${pools.length} pools`);
 * ```
 */
export async function getPools(network: Network = NETWORK): Promise<string[]> {
  const aptos = getAptosClient(network);
  
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_pools`,
      functionArguments: [],
    }
  });
  
  // Result is an array of {inner: "0x..."} objects
  const pools = result[0] as Array<{inner: string}>;
  return pools.map(p => p.inner);
}

/**
 * Get pool balance (APT reserves)
 * 
 * @param poolId - Pool object address
 * @param network - Network to use (default: TESTNET)
 * @returns APT balance in octas
 * 
 * @example
 * ```typescript
 * const balance = await getPoolBalance("0x1234...");
 * console.log(`Pool has ${octasToApt(balance)} APT`);
 * ```
 */
export async function getPoolBalance(
  poolId: string,
  network: Network = NETWORK
): Promise<number> {
  const aptos = getAptosClient(network);
  
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_pool_balance`,
      functionArguments: [poolId],
    }
  });
  
  return parseInt(result[0] as string);
}

// ============================================================================
// EXPORTS
// ============================================================================

export default {
  // Constants
  CONTRACT_ADDRESS,
  NETWORK,
  
  // Main functions
  createPool,
  buyTokens,
  sellTokens,
  
  // View functions
  getPools,
  getPoolBalance,
  
  // Helper functions
  getAptosClient,
  getExplorerUrl,
  aptToOctas,
  octasToApt,
  tokensToBaseUnits,
  baseUnitsToTokens,
};
