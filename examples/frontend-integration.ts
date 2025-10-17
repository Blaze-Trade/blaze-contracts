/**
 * Blaze Launchpad V2 - Frontend Integration Example
 * 
 * This file demonstrates how to interact with the deployed contract
 * using the Aptos TypeScript SDK.
 */

import { 
  Aptos, 
  AptosConfig, 
  Network, 
  Account,
  Ed25519PrivateKey
} from "@aptos-labs/ts-sdk";

// Configuration
const NETWORK = Network.TESTNET; // or Network.MAINNET
const CONTRACT_ADDRESS = "YOUR_CONTRACT_ADDRESS_HERE"; // Replace with your deployed contract

// Initialize Aptos client
const config = new AptosConfig({ network: NETWORK });
const aptos = new Aptos(config);

// ==================== Account Setup ====================

/**
 * Create or import an account
 */
export async function setupAccount(privateKeyHex?: string): Promise<Account> {
  if (privateKeyHex) {
    // Import existing account
    const privateKey = new Ed25519PrivateKey(privateKeyHex);
    return Account.fromPrivateKey({ privateKey });
  } else {
    // Generate new account
    return Account.generate();
  }
}

// ==================== View Functions ====================

/**
 * Get admin address
 */
export async function getAdmin(): Promise<string> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_admin`,
      typeArguments: [],
      functionArguments: [],
    },
  });
  return result[0] as string;
}

/**
 * Get treasury address
 */
export async function getTreasury(): Promise<string> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_treasury`,
      typeArguments: [],
      functionArguments: [],
    },
  });
  return result[0] as string;
}

/**
 * Get APT/USD price from oracle (in cents)
 */
export async function getAptUsdPrice(): Promise<number> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_apt_usd_price`,
      typeArguments: [],
      functionArguments: [],
    },
  });
  return Number(result[0]);
}

/**
 * Get oracle data (price, last_update, oracle_address)
 */
export async function getOracleData(): Promise<{
  price: number;
  lastUpdate: number;
  oracleAddress: string;
}> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_oracle_data`,
      typeArguments: [],
      functionArguments: [],
    },
  });
  return {
    price: Number(result[0]),
    lastUpdate: Number(result[1]),
    oracleAddress: result[2] as string,
  };
}

/**
 * Get all pool IDs
 */
export async function getAllPools(): Promise<string[]> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_pools`,
      typeArguments: [],
      functionArguments: [],
    },
  });
  return result[0] as string[];
}

/**
 * Get pool data
 */
export async function getPool(poolId: string): Promise<any> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_pool`,
      typeArguments: [],
      functionArguments: [poolId],
    },
  });
  return result;
}

/**
 * Get current price per token in APT
 */
export async function getCurrentPrice(poolId: string): Promise<number> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_current_price`,
      typeArguments: [],
      functionArguments: [poolId],
    },
  });
  return Number(result[0]);
}

/**
 * Get current token supply
 */
export async function getCurrentSupply(poolId: string): Promise<string> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_current_supply`,
      typeArguments: [],
      functionArguments: [poolId],
    },
  });
  return result[0] as string;
}

/**
 * Calculate market cap in USD cents
 */
export async function calculateMarketCapUsd(poolId: string): Promise<number> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::calculate_market_cap_usd`,
      typeArguments: [],
      functionArguments: [poolId],
    },
  });
  return Number(result[0]);
}

/**
 * Check if pool has reached migration threshold
 */
export async function isMigrationThresholdReached(poolId: string): Promise<boolean> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::is_migration_threshold_reached`,
      typeArguments: [],
      functionArguments: [poolId],
    },
  });
  return result[0] as boolean;
}

/**
 * Calculate tokens received for APT amount (before fees)
 */
export async function calculateCurvedMintReturn(
  poolId: string,
  aptAmount: number
): Promise<number> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::calculate_curved_mint_return`,
      typeArguments: [],
      functionArguments: [poolId, aptAmount],
    },
  });
  return Number(result[0]);
}

/**
 * Get buy and sell fees
 */
export async function getFees(): Promise<{ buyFeeBps: number; sellFeeBps: number }> {
  const result = await aptos.view({
    payload: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::get_fees`,
      typeArguments: [],
      functionArguments: [],
    },
  });
  return {
    buyFeeBps: Number(result[0]),
    sellFeeBps: Number(result[1]),
  };
}

// ==================== Write Functions ====================

/**
 * Create a new token pool
 */
export async function createPool(
  account: Account,
  params: {
    name: string;
    ticker: string;
    tokenImageUri: string;
    description?: string;
    website?: string;
    twitter?: string;
    telegram?: string;
    discord?: string;
    maxSupply?: number;
    decimals: number;
    reserveRatio: number;
    initialAptReserve: number;
    marketCapThresholdUsd?: number;
  }
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: account.accountAddress,
    data: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::create_pool`,
      typeArguments: [],
      functionArguments: [
        params.name,
        params.ticker,
        params.tokenImageUri,
        params.description ? [params.description] : [],
        params.website ? [params.website] : [],
        params.twitter ? [params.twitter] : [],
        params.telegram ? [params.telegram] : [],
        params.discord ? [params.discord] : [],
        params.maxSupply ? [params.maxSupply] : [],
        params.decimals,
        params.reserveRatio,
        params.initialAptReserve,
        params.marketCapThresholdUsd ? [params.marketCapThresholdUsd] : [],
      ],
    },
  });

  const committedTxn = await aptos.signAndSubmitTransaction({
    signer: account,
    transaction,
  });

  await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
  return committedTxn.hash;
}

/**
 * Buy tokens
 */
export async function buyTokens(
  account: Account,
  poolId: string,
  aptAmount: number,
  minTokensOut: number,
  deadline: number
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: account.accountAddress,
    data: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::buy`,
      typeArguments: [],
      functionArguments: [poolId, aptAmount, minTokensOut, deadline],
    },
  });

  const committedTxn = await aptos.signAndSubmitTransaction({
    signer: account,
    transaction,
  });

  await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
  return committedTxn.hash;
}

/**
 * Sell tokens
 */
export async function sellTokens(
  account: Account,
  poolId: string,
  tokenAmount: number,
  minAptOut: number,
  deadline: number
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: account.accountAddress,
    data: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::sell`,
      typeArguments: [],
      functionArguments: [poolId, tokenAmount, minAptOut, deadline],
    },
  });

  const committedTxn = await aptos.signAndSubmitTransaction({
    signer: account,
    transaction,
  });

  await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
  return committedTxn.hash;
}

/**
 * Update oracle price (Admin only)
 */
export async function updateOraclePrice(
  adminAccount: Account,
  newPrice: number,
  oracleAddress: string
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: adminAccount.accountAddress,
    data: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::update_oracle_price`,
      typeArguments: [],
      functionArguments: [newPrice, oracleAddress],
    },
  });

  const committedTxn = await aptos.signAndSubmitTransaction({
    signer: adminAccount,
    transaction,
  });

  await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
  return committedTxn.hash;
}

/**
 * Force migrate to Hyperion (Admin only)
 */
export async function forceMigrateToHyperion(
  adminAccount: Account,
  poolId: string
): Promise<string> {
  const transaction = await aptos.transaction.build.simple({
    sender: adminAccount.accountAddress,
    data: {
      function: `${CONTRACT_ADDRESS}::launchpad_v2::force_migrate_to_hyperion`,
      typeArguments: [],
      functionArguments: [poolId],
    },
  });

  const committedTxn = await aptos.signAndSubmitTransaction({
    signer: adminAccount,
    transaction,
  });

  await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
  return committedTxn.hash;
}

// ==================== Helper Functions ====================

/**
 * Format price for display
 */
export function formatPrice(priceInOctas: number, decimals: number = 8): string {
  return (priceInOctas / Math.pow(10, decimals)).toFixed(decimals);
}

/**
 * Format USD amount from cents
 */
export function formatUsdFromCents(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}

/**
 * Get current Unix timestamp + offset in seconds
 */
export function getDeadline(offsetSeconds: number = 300): number {
  return Math.floor(Date.now() / 1000) + offsetSeconds;
}

/**
 * Convert APT to octas
 */
export function aptToOctas(apt: number): number {
  return apt * 100000000;
}

/**
 * Convert octas to APT
 */
export function octasToApt(octas: number): number {
  return octas / 100000000;
}

// ==================== Example Usage ====================

async function exampleUsage() {
  console.log("🚀 Blaze Launchpad V2 - Frontend Integration Example");
  console.log("====================================================");

  // Setup account
  const account = await setupAccount();
  console.log(`📍 Account: ${account.accountAddress}`);

  try {
    // Get admin and treasury
    const admin = await getAdmin();
    const treasury = await getTreasury();
    console.log(`👤 Admin: ${admin}`);
    console.log(`💰 Treasury: ${treasury}`);

    // Get oracle data
    const oracleData = await getOracleData();
    console.log(`📊 APT Price: ${formatUsdFromCents(oracleData.price)}`);
    console.log(`🕐 Last Update: ${new Date(oracleData.lastUpdate * 1000).toISOString()}`);

    // Get all pools
    const pools = await getAllPools();
    console.log(`🏊 Total Pools: ${pools.length}`);

    if (pools.length > 0) {
      const firstPool = pools[0];
      console.log(`\n📦 Pool: ${firstPool}`);

      // Get pool details
      const supply = await getCurrentSupply(firstPool);
      const price = await getCurrentPrice(firstPool);
      const marketCap = await calculateMarketCapUsd(firstPool);
      const isMigrationReady = await isMigrationThresholdReached(firstPool);

      console.log(`  Supply: ${supply}`);
      console.log(`  Price: ${octasToApt(price)} APT`);
      console.log(`  Market Cap: ${formatUsdFromCents(marketCap)}`);
      console.log(`  Migration Ready: ${isMigrationReady}`);

      // Calculate purchase
      const aptAmount = aptToOctas(0.1); // 0.1 APT
      const tokensOut = await calculateCurvedMintReturn(firstPool, aptAmount);
      console.log(`\n💱 0.1 APT = ${formatPrice(tokensOut)} tokens`);
    }

    // Example: Create a new pool
    console.log("\n🔨 Creating new pool...");
    const txHash = await createPool(account, {
      name: "Test Token",
      ticker: "TEST",
      tokenImageUri: "https://example.com/test.png",
      description: "A test token for demonstration",
      website: "https://example.com",
      twitter: "@testtoken",
      decimals: 8,
      reserveRatio: 50,
      initialAptReserve: aptToOctas(1), // 1 APT
      marketCapThresholdUsd: 7500000, // $75,000
    });
    console.log(`✅ Pool created! TX: ${txHash}`);

  } catch (error) {
    console.error("❌ Error:", error);
  }
}

// Run example if this file is executed directly
if (require.main === module) {
  exampleUsage().catch(console.error);
}

// Export all functions
export default {
  // Account
  setupAccount,
  
  // View functions
  getAdmin,
  getTreasury,
  getAptUsdPrice,
  getOracleData,
  getAllPools,
  getPool,
  getCurrentPrice,
  getCurrentSupply,
  calculateMarketCapUsd,
  isMigrationThresholdReached,
  calculateCurvedMintReturn,
  getFees,
  
  // Write functions
  createPool,
  buyTokens,
  sellTokens,
  updateOraclePrice,
  forceMigrateToHyperion,
  
  // Helpers
  formatPrice,
  formatUsdFromCents,
  getDeadline,
  aptToOctas,
  octasToApt,
};
