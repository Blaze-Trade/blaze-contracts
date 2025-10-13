# Launchpad V2 Smart Contract Specification

**Module**: `blaze_token_launchpad::launchpad_v2`  
**Network**: Aptos Mainnet  
**Contract Address**: `0x9239ac2bb7bb998c6d19d1b309dd2093f130185710415832caf30bf0c99d678a`

## Table of Contents
- [Overview](#overview)
- [Write Functions](#write-functions)
- [View Functions](#view-functions)
- [Events](#events)
- [Data Structures](#data-structures)
- [Error Codes](#error-codes)
- [Integration Examples](#integration-examples)

---

## Overview

The Launchpad V2 contract implements a **Bancor bonding curve** token launchpad with enhanced metadata support. Users can create fungible asset pools, buy/sell tokens through automated market making, and track comprehensive token information including social links and project details.

### Key Features
- ✅ Create token pools with custom bonding curves
- ✅ Buy/sell tokens via Bancor formula
- ✅ Configurable reserve ratios (1-100%)
- ✅ Enhanced metadata (name, ticker, image, description, socials)
- ✅ Slippage protection and deadline enforcement
- ✅ Fee collection system
- ✅ Market cap threshold for DEX migration
- ✅ Admin controls for pool management

---

## Write Functions

### 1. `create_pool`
Creates a new token pool with Bancor bonding curve pricing.

**Signature:**
```move
public entry fun create_pool(
    sender: &signer,
    name: String,
    ticker: String,
    token_image_uri: String,
    description: Option<String>,
    website: Option<String>,
    twitter: Option<String>,
    telegram: Option<String>,
    discord: Option<String>,
    max_supply: Option<u128>,
    decimals: u8,
    reserve_ratio: u64,
    initial_apt_reserve: u64,
    market_cap_threshold_usd: Option<u64>
)
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sender` | `&signer` | Pool creator's signer |
| `name` | `String` | Full token name (e.g., "Blaze Token") |
| `ticker` | `String` | Token symbol, 1-10 chars (e.g., "BLAZE") |
| `token_image_uri` | `String` | IPFS or HTTP URL to token image |
| `description` | `Option<String>` | Token description (optional) |
| `website` | `Option<String>` | Project website URL (optional) |
| `twitter` | `Option<String>` | Twitter handle (optional) |
| `telegram` | `Option<String>` | Telegram link (optional) |
| `discord` | `Option<String>` | Discord invite link (optional) |
| `max_supply` | `Option<u128>` | Maximum token supply (optional, 0 = unlimited) |
| `decimals` | `u8` | Token decimals (typically 6 or 8) |
| `reserve_ratio` | `u64` | Bancor reserve ratio 1-100 (50 = 50%) |
| `initial_apt_reserve` | `u64` | Initial APT reserve in octas (min 0.1 APT = 10000000) |
| `market_cap_threshold_usd` | `Option<u64>` | USD market cap for DEX migration (optional) |

**Returns:** Creates a fungible asset object

**Events Emitted:** `CreatePoolEvent`

**Example (TypeScript SDK):**
```typescript
const payload = {
  function: `${MODULE_ADDRESS}::launchpad_v2::create_pool`,
  type_arguments: [],
  arguments: [
    "My Token",                    // name
    "MTK",                         // ticker
    "https://ipfs.io/...",        // token_image_uri
    ["A cool token"],             // description (Option)
    ["https://mytoken.com"],      // website (Option)
    ["@mytoken"],                 // twitter (Option)
    ["t.me/mytoken"],             // telegram (Option)
    ["discord.gg/mytoken"],       // discord (Option)
    [1000000000000],              // max_supply (Option, with decimals)
    8,                            // decimals
    50,                           // reserve_ratio (50%)
    100000000,                    // initial_apt_reserve (1 APT)
    [10000000]                    // market_cap_threshold_usd (Option)
  ]
};
```

---

### 2. `buy`
Purchase tokens from a pool using APT via the Bancor bonding curve.

**Signature:**
```move
public entry fun buy(
    sender: &signer,
    pool_id: Object<Metadata>,
    apt_amount_in: u64,
    min_tokens_out: u64,
    deadline: u64
)
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sender` | `&signer` | Buyer's signer |
| `pool_id` | `Object<Metadata>` | Token pool object address |
| `apt_amount_in` | `u64` | APT amount to spend (in octas) |
| `min_tokens_out` | `u64` | Minimum tokens to receive (slippage protection) |
| `deadline` | `u64` | Unix timestamp deadline (use 0 for no deadline) |

**Returns:** Tokens are deposited to sender's account

**Events Emitted:** `BuyEvent`

**Example (TypeScript SDK):**
```typescript
const poolAddress = "0xabc..."; // Token pool object address
const aptAmount = 50000000; // 0.5 APT
const minTokens = 450000000; // Min 4.5 tokens (with slippage)
const deadline = Math.floor(Date.now() / 1000) + 300; // 5 min from now

const payload = {
  function: `${MODULE_ADDRESS}::launchpad_v2::buy`,
  type_arguments: [],
  arguments: [
    poolAddress,
    aptAmount,
    minTokens,
    deadline
  ]
};
```

---

### 3. `sell`
Sell tokens back to the pool for APT via the Bancor bonding curve.

**Signature:**
```move
public entry fun sell(
    sender: &signer,
    pool_id: Object<Metadata>,
    token_amount_in: u64,
    min_apt_out: u64,
    deadline: u64
)
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sender` | `&signer` | Seller's signer |
| `pool_id` | `Object<Metadata>` | Token pool object address |
| `token_amount_in` | `u64` | Token amount to sell (in base units) |
| `min_apt_out` | `u64` | Minimum APT to receive (slippage protection) |
| `deadline` | `u64` | Unix timestamp deadline (use 0 for no deadline) |

**Returns:** APT is deposited to sender's account

**Events Emitted:** `SellEvent`

**Example (TypeScript SDK):**
```typescript
const payload = {
  function: `${MODULE_ADDRESS}::launchpad_v2::sell`,
  type_arguments: [],
  arguments: [
    poolAddress,
    500000000,  // 5 tokens
    45000000,   // Min 0.45 APT
    deadline
  ]
};
```

---

### 4. `set_admin`
Transfer admin privileges to a new address. (Admin only)

**Signature:**
```move
public entry fun set_admin(admin: &signer, new_admin: address)
```

---

### 5. `set_treasury`
Update the treasury address for fee collection. (Admin only)

**Signature:**
```move
public entry fun set_treasury(admin: &signer, new_treasury: address)
```

---

### 6. `update_fee`
Update buy and sell fee percentages. (Admin only)

**Signature:**
```move
public entry fun update_fee(admin: &signer, buy_fee_bps: u64, sell_fee_bps: u64)
```

**Parameters:**
- `buy_fee_bps`: Buy fee in basis points (100 = 1%)
- `sell_fee_bps`: Sell fee in basis points (100 = 1%)

---

### 7. `update_pool_settings`
Update pool-specific settings. (Admin only)

**Signature:**
```move
public entry fun update_pool_settings(
    admin: &signer,
    pool_id: Object<Metadata>,
    trading_enabled: bool,
    market_cap_threshold_usd: u64
)
```

---

### 8. `migrate_to_dex`
Migrate pool liquidity to Hyperion DEX when market cap threshold is reached.

**Signature:**
```move
public entry fun migrate_to_dex(admin: &signer, pool_id: Object<Metadata>)
```

**Status:** 🚧 Not yet implemented (requires Hyperion integration)

---

## View Functions

All view functions are read-only and don't require gas.

### Pool Information

#### `get_pool_info`
Get comprehensive pool information including metadata and curve parameters.

```move
#[view]
public fun get_pool_info(pool_id: Object<Metadata>): PoolInfo
```

**Returns:**
```typescript
{
  creator: string,              // Pool creator address
  name: string,                 // Token name
  ticker: string,               // Token symbol
  token_image_uri: string,      // Image URL
  description: string | null,   // Description
  website: string | null,       // Website URL
  twitter: string | null,       // Twitter handle
  telegram: string | null,      // Telegram link
  discord: string | null,       // Discord link
  apt_reserve: string,          // Current APT reserve (in octas)
  token_supply: string,         // Current token supply (in base units)
  reserve_ratio: string,        // Reserve ratio (1-100)
  max_supply: string,           // Max supply (0 = unlimited)
  market_cap_threshold_usd: string, // Market cap threshold for migration
  trading_enabled: boolean,     // Whether trading is enabled
  migrated_to_dex: boolean,     // Whether pool migrated to DEX
  creation_time: string         // Unix timestamp of creation
}
```

**Example (TypeScript SDK):**
```typescript
const [poolInfo] = await client.view({
  function: `${MODULE_ADDRESS}::launchpad_v2::get_pool_info`,
  type_arguments: [],
  arguments: [poolAddress]
});
```

---

#### `get_current_price`
Get current token price in APT.

```move
#[view]
public fun get_current_price(pool_id: Object<Metadata>): u64
```

**Returns:** Price in APT per token (scaled by decimals)

---

#### `get_market_cap`
Get current market capitalization in APT.

```move
#[view]
public fun get_market_cap(pool_id: Object<Metadata>): u128
```

**Returns:** Market cap = (total supply × current price)

---

#### `get_curve_data`
Get bonding curve parameters.

```move
#[view]
public fun get_curve_data(pool_id: Object<Metadata>): CurveData
```

**Returns:**
```typescript
{
  reserve_ratio: string,     // Reserve ratio percentage
  apt_reserve: string,       // Current APT reserve
  token_supply: string       // Current token supply
}
```

---

### Price Calculations

#### `calculate_curved_mint_return`
Calculate how many tokens will be received for a given APT amount (before fees).

```move
#[view]
public fun calculate_curved_mint_return(
    pool_id: Object<Metadata>,
    apt_amount: u64
): u64
```

**Example:**
```typescript
const [tokensOut] = await client.view({
  function: `${MODULE_ADDRESS}::launchpad_v2::calculate_curved_mint_return`,
  arguments: [poolAddress, 100000000] // For 1 APT
});
```

---

#### `calculate_curved_burn_return`
Calculate how much APT will be received for selling tokens (before fees).

```move
#[view]
public fun calculate_curved_burn_return(
    pool_id: Object<Metadata>,
    token_amount: u64
): u64
```

---

#### `calculate_buy_amount_out`
Calculate final token amount after fees.

```move
#[view]
public fun calculate_buy_amount_out(
    pool_id: Object<Metadata>,
    apt_amount_in: u64
): u64
```

---

#### `calculate_sell_amount_out`
Calculate final APT amount after fees.

```move
#[view]
public fun calculate_sell_amount_out(
    pool_id: Object<Metadata>,
    token_amount_in: u64
): u64
```

---

### Registry Functions

#### `get_pools`
Get all pool addresses.

```move
#[view]
public fun get_pools(): vector<Object<Metadata>>
```

**Returns:** Array of pool object addresses

---

#### `get_tokens`
Get all token metadata objects.

```move
#[view]
public fun get_tokens(): vector<Object<Metadata>>
```

---

#### `get_pool_count`
Get total number of pools.

```move
#[view]
public fun get_pool_count(): u64
```

---

### Configuration

#### `get_fees`
Get current buy and sell fee percentages.

```move
#[view]
public fun get_fees(): (u64, u64)
```

**Returns:** `(buy_fee_bps, sell_fee_bps)` - fees in basis points (100 = 1%)

---

#### `get_admin`
Get current admin address.

```move
#[view]
public fun get_admin(): address
```

---

#### `get_treasury`
Get current treasury address.

```move
#[view]
public fun get_treasury(): address
```

---

## Events

All events are emitted on-chain and can be tracked via indexers.

### CreatePoolEvent
```typescript
{
  pool_id: string,                    // Pool object address
  creator: string,                    // Creator address
  name: string,                       // Token name
  ticker: string,                     // Token symbol
  reserve_ratio: string,              // Reserve ratio
  initial_reserve: string,            // Initial APT reserve
  market_cap_threshold_usd: string,   // Market cap threshold
  timestamp: string                   // Creation timestamp
}
```

### BuyEvent
```typescript
{
  buyer: string,              // Buyer address
  pool_id: string,            // Pool object address
  apt_amount_in: string,      // APT spent
  tokens_out: string,         // Tokens received
  fee_amount: string,         // Fee paid (in APT)
  new_price: string,          // New price after trade
  timestamp: string           // Trade timestamp
}
```

### SellEvent
```typescript
{
  seller: string,             // Seller address
  pool_id: string,            // Pool object address
  tokens_in: string,          // Tokens sold
  apt_amount_out: string,     // APT received
  fee_amount: string,         // Fee paid (in tokens)
  new_price: string,          // New price after trade
  timestamp: string           // Trade timestamp
}
```

### PoolSettingsUpdatedEvent
```typescript
{
  pool_id: string,                  // Pool object address
  trading_enabled: boolean,         // New trading status
  market_cap_threshold_usd: string, // New threshold
  timestamp: string                 // Update timestamp
}
```

### FeeUpdatedEvent
```typescript
{
  buy_fee_bps: string,    // New buy fee
  sell_fee_bps: string,   // New sell fee
  timestamp: string       // Update timestamp
}
```

### AdminChangedEvent
```typescript
{
  old_admin: string,      // Previous admin
  new_admin: string,      // New admin
  timestamp: string       // Change timestamp
}
```

### TreasuryChangedEvent
```typescript
{
  old_treasury: string,   // Previous treasury
  new_treasury: string,   // New treasury
  timestamp: string       // Change timestamp
}
```

### MigrateToDexEvent
```typescript
{
  pool_id: string,        // Pool object address
  dex_pool_id: string,    // DEX pool address
  timestamp: string       // Migration timestamp
}
```

---

## Data Structures

### PoolInfo
Complete pool information returned by `get_pool_info()`.

```typescript
interface PoolInfo {
  creator: string;
  name: string;
  ticker: string;
  token_image_uri: string;
  description: string | null;
  website: string | null;
  twitter: string | null;
  telegram: string | null;
  discord: string | null;
  apt_reserve: string;
  token_supply: string;
  reserve_ratio: string;
  max_supply: string;
  market_cap_threshold_usd: string;
  trading_enabled: boolean;
  migrated_to_dex: boolean;
  creation_time: string;
}
```

### CurveData
Bonding curve parameters.

```typescript
interface CurveData {
  reserve_ratio: string;
  apt_reserve: string;
  token_supply: string;
}
```

---

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 1 | `EONLY_ADMIN` | Only admin can perform this action |
| 100 | `EINVALID_RESERVE_RATIO` | Reserve ratio must be 1-100 |
| 101 | `EINVALID_TICKER_LENGTH` | Ticker must be 1-10 characters |
| 102 | `EINVALID_INITIAL_RESERVE` | Initial reserve must be > 0 |
| 103 | `EINSUFFICIENT_LIQUIDITY` | Insufficient liquidity in pool |
| 104 | `ETRADING_DISABLED` | Trading is disabled for this pool |
| 105 | `ESLIPPAGE_EXCEEDED` | Output below minimum (slippage too high) |
| 106 | `EDEADLINE_PASSED` | Transaction deadline has passed |
| 107 | `EPOOL_NOT_FOUND` | Pool does not exist |
| 108 | `EINVALID_AMOUNT` | Amount must be > 0 |
| 109 | `EMAX_SUPPLY_EXCEEDED` | Would exceed maximum supply |

---

## Integration Examples

### Complete Buy Flow

```typescript
import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";

const MODULE_ADDRESS = "0x9239ac2bb7bb998c6d19d1b309dd2093f130185710415832caf30bf0c99d678a";
const config = new AptosConfig({ network: Network.MAINNET });
const client = new Aptos(config);

async function buyTokens(
  account: Account,
  poolAddress: string,
  aptAmount: number,
  slippageBps: number = 100 // 1% slippage
) {
  // 1. Get expected token output
  const [expectedTokens] = await client.view({
    function: `${MODULE_ADDRESS}::launchpad_v2::calculate_buy_amount_out`,
    arguments: [poolAddress, aptAmount]
  });

  // 2. Calculate minimum with slippage
  const minTokensOut = Math.floor(
    Number(expectedTokens) * (10000 - slippageBps) / 10000
  );

  // 3. Set deadline (5 minutes)
  const deadline = Math.floor(Date.now() / 1000) + 300;

  // 4. Build and submit transaction
  const transaction = await client.transaction.build.simple({
    sender: account.accountAddress,
    data: {
      function: `${MODULE_ADDRESS}::launchpad_v2::buy`,
      functionArguments: [poolAddress, aptAmount, minTokensOut, deadline]
    }
  });

  const committedTxn = await client.signAndSubmitTransaction({
    signer: account,
    transaction
  });

  await client.waitForTransaction({ transactionHash: committedTxn.hash });
  
  return committedTxn.hash;
}
```

### Fetch All Pools

```typescript
async function fetchAllPools() {
  // Get all pool addresses
  const [poolAddresses] = await client.view({
    function: `${MODULE_ADDRESS}::launchpad_v2::get_pools`,
    arguments: []
  });

  // Fetch detailed info for each pool
  const pools = await Promise.all(
    poolAddresses.map(async (address) => {
      const [info] = await client.view({
        function: `${MODULE_ADDRESS}::launchpad_v2::get_pool_info`,
        arguments: [address]
      });
      return { address, ...info };
    })
  );

  return pools;
}
```

### Listen to Buy Events

```typescript
async function watchBuyEvents(poolAddress: string) {
  // Using Aptos Indexer GraphQL
  const query = `
    query GetBuyEvents($poolAddress: String!) {
      events(
        where: {
          account_address: { _eq: "${MODULE_ADDRESS}" }
          type: { _eq: "${MODULE_ADDRESS}::launchpad_v2::BuyEvent" }
          data: { _contains: { pool_id: $poolAddress } }
        }
        order_by: { transaction_version: desc }
        limit: 50
      ) {
        sequence_number
        transaction_version
        data
      }
    }
  `;

  // Execute query against Aptos indexer
  // ...
}
```

### Calculate Price Impact

```typescript
async function calculatePriceImpact(
  poolAddress: string,
  aptAmount: number
): Promise<number> {
  // Get current price
  const [currentPrice] = await client.view({
    function: `${MODULE_ADDRESS}::launchpad_v2::get_current_price`,
    arguments: [poolAddress]
  });

  // Get expected tokens
  const [tokensOut] = await client.view({
    function: `${MODULE_ADDRESS}::launchpad_v2::calculate_buy_amount_out`,
    arguments: [poolAddress, aptAmount]
  });

  // Calculate average price
  const avgPrice = aptAmount / Number(tokensOut);
  
  // Calculate price impact percentage
  const priceImpact = ((avgPrice - Number(currentPrice)) / Number(currentPrice)) * 100;
  
  return priceImpact;
}
```

---

## Best Practices

### 1. Always Use Slippage Protection
```typescript
// ❌ Bad: No slippage protection
buy(account, poolAddress, aptAmount, 0, deadline);

// ✅ Good: 1% slippage tolerance
const minOut = expectedTokens * 0.99;
buy(account, poolAddress, aptAmount, minOut, deadline);
```

### 2. Set Reasonable Deadlines
```typescript
// ✅ Good: 5 minute deadline
const deadline = Math.floor(Date.now() / 1000) + 300;
```

### 3. Handle Errors Gracefully
```typescript
try {
  await buyTokens(account, poolAddress, amount);
} catch (error) {
  if (error.message.includes('ESLIPPAGE_EXCEEDED')) {
    // Increase slippage tolerance or retry
  } else if (error.message.includes('ETRADING_DISABLED')) {
    // Notify user that trading is paused
  }
}
```

### 4. Validate Pool Before Trading
```typescript
const [poolInfo] = await client.view({
  function: `${MODULE_ADDRESS}::launchpad_v2::get_pool_info`,
  arguments: [poolAddress]
});

if (!poolInfo.trading_enabled) {
  throw new Error("Trading is disabled for this pool");
}
```

---

## Rate Limits & Performance

- **View Functions**: No rate limits, can be called as often as needed
- **Write Functions**: Limited by Aptos transaction throughput (~7,000 TPS)
- **Indexer Queries**: Rate limited by provider (typically 100-1000 req/min)

### Caching Recommendations
- Cache pool info for 30-60 seconds
- Cache current price for 5-10 seconds
- Always fetch fresh data before user transactions

---

## Support & Resources

- **Contract Source**: [GitHub Repository](https://github.com/Blaze-Trade/blaze-contracts)
- **Aptos SDK**: [TypeScript SDK Docs](https://aptos.dev/sdks/ts-sdk/)
- **Aptos Explorer**: [View Contract](https://explorer.aptoslabs.com/account/${MODULE_ADDRESS})

---

**Last Updated**: October 13, 2025  
**Contract Version**: 2.0.0
