# Product Requirements Document: Launchpad V2 - Enhanced Token Launch Platform

**Version:** 2.0  
**Date:** October 13, 2025  
**Status:** Planning  

---

## Executive Summary

This PRD outlines the enhancement of the `blaze_token_launchpad::launchpad` module to provide a comprehensive token launch platform with improved metadata management, Bancor-based bonding curve pricing, and automatic liquidity migration to Hyperion DEX upon reaching a market cap threshold of $75,000.

---

## Current State

The existing launchpad supports:
- Basic FA creation with optional mint fees and per-address mint limits
- Quadratic bonding curve with buy/sell functionality
- APT liquidity management via resource account
- Manual bonding curve deactivation at target supply

**Limitations:**
- Limited token metadata (no social links, detailed descriptions)
- Simple quadratic pricing (not Bancor formula)
- No automatic DEX liquidity deployment
- No configurable fee structure per pool
- Limited administrative controls

---

## Goals and Objectives

### Primary Goals
1. **Enhanced Token Metadata**: Support comprehensive token information including images, descriptions, and social links
2. **Market Cap-Triggered Liquidity**: Automatically deploy liquidity to Hyperion DEX at $75,000 market cap
3. **Bancor Pricing Model**: Implement industry-standard Bancor bonding curve formula
4. **Flexible Pool Management**: Per-pool configuration and fee structures
5. **Advanced Administration**: Granular control over pools, fees, and treasury

### Success Criteria
- Tokens can be created with full metadata (name, ticker, image, description, social links)
- Liquidity automatically migrates to Hyperion DEX at $75,000 market cap
- Pricing accurately follows Bancor formula
- Admins can configure per-pool settings and fees
- All read functions return accurate, real-time data

---

## Feature Requirements

### 1. Enhanced Token Metadata

#### Token Creation Fields
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `String` | Yes | Full token name (e.g., "Fun Token") |
| `ticker` | `String` | Yes | Short symbol (e.g., "$FUN", max 10 chars) |
| `token_image_uri` | `String` | Yes | IPFS/HTTP URL to token image |
| `description` | `String` | No | Token description (max 500 chars) |
| `website_url` | `String` | No | Project website |
| `twitter_url` | `String` | No | Twitter/X handle or URL |
| `telegram_url` | `String` | No | Telegram group/channel |
| `discord_url` | `String` | No | Discord server invite |

#### Storage Structure
```move
struct TokenMetadata has key, store {
    name: String,
    ticker: String,
    token_image_uri: String,
    description: Option<String>,
    social_links: SocialLinks,
    created_at: u64,  // timestamp
    creator: address
}

struct SocialLinks has store, copy, drop {
    website: Option<String>,
    twitter: Option<String>,
    telegram: Option<String>,
    discord: Option<String>
}
```

---

### 2. Market Cap Threshold & Hyperion DEX Integration

#### Requirements
- **Market Cap Threshold**: $75,000 USD (configurable by admin)
- **Price Oracle**: Integrate APT/USD price feed to calculate market cap
- **Automatic Migration**: When `market_cap >= threshold`, trigger liquidity deployment
- **DEX Integration**: Call Hyperion DEX contract to create pool and add liquidity
- **Lock Mechanism**: Prevent further bonding curve trades after migration

#### Workflow
1. User buys tokens via bonding curve
2. System calculates current market cap: `market_cap = total_supply * current_price * apt_usd_price`
3. If `market_cap >= $75,000`:
   - Deactivate bonding curve (`is_active = false`)
   - Calculate liquidity amounts (APT + tokens)
   - Call Hyperion DEX `create_pool` and `add_liquidity`
   - Emit `LiquidityMigratedEvent`
   - Lock remaining supply or burn

#### Storage Structure
```move
struct PoolSettings has key, store {
    market_cap_threshold_usd: u64,  // in cents (7500000 = $75,000)
    hyperion_pool_address: Option<address>,  // set after migration
    migration_completed: bool,
    migration_timestamp: Option<u64>
}
```

---

### 3. Bancor Bonding Curve Formula

Replace current quadratic formula with industry-standard Bancor formula.

#### Bancor Formula

**Purchase Return (tokens received for APT):**
```
return = supply * ((1 + deposit / balance) ^ (reserve_ratio / 100) - 1)
```

**Sale Return (APT received for tokens):**
```
return = balance * (1 - (1 - amount / supply) ^ (100 / reserve_ratio))
```

Where:
- `supply`: Current token supply
- `balance`: APT reserve balance
- `deposit`: APT amount to spend
- `amount`: Token amount to sell
- `reserve_ratio`: Connector weight (1-100), typically 50 for balanced curve

#### Implementation Notes
- Use fixed-point arithmetic for precision (e.g., 18 decimals)
- Handle edge cases: zero supply, zero balance
- Prevent overflow with safe math operations

---

## Function Specifications

### Write Functions

#### 1. `buy`
```move
public entry fun buy(
    sender: &signer,
    pool_id: Object<Metadata>,
    min_tokens_out: u64,  // slippage protection
    deadline: u64  // timestamp
) acquires Pool, PoolSettings, LiquidityPool, ResourceAccountCapability
```
**Description**: Purchase tokens using APT via Bancor bonding curve.

**Logic**:
1. Verify pool exists and curve is active
2. Calculate tokens to mint using `calculate_purchance_return_bancor`
3. Assert `tokens_out >= min_tokens_out` (slippage check)
4. Assert `current_timestamp <= deadline`
5. Transfer APT from user to pool
6. Mint tokens to user
7. Check if market cap threshold reached → trigger migration if yes
8. Emit `BuyEvent`

---

#### 2. `create_pool`
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
    reserve_ratio: u64,  // 1-100
    initial_apt_reserve: u64,
    market_cap_threshold_usd: u64
) acquires Registry, Config
```
**Description**: Create a new token pool with full metadata and Bancor curve.

**Logic**:
1. Validate inputs (ticker length, reserve ratio range, etc.)
2. Create FA object and store `FAController`
3. Store `TokenMetadata` with all metadata fields
4. Store `BancorCurve { reserve_ratio, reserve_balance: initial_apt_reserve }`
5. Store `PoolSettings { market_cap_threshold_usd, ... }`
6. If `initial_apt_reserve > 0`, transfer APT from sender to pool
7. Add to `Registry`
8. Emit `CreatePoolEvent`

---

#### 3. `sell`
```move
public entry fun sell(
    sender: &signer,
    pool_id: Object<Metadata>,
    token_amount: u64,
    min_apt_out: u64,  // slippage protection
    deadline: u64
) acquires Pool, BancorCurve, LiquidityPool, ResourceAccountCapability
```
**Description**: Sell tokens for APT via Bancor curve.

**Logic**:
1. Verify curve is active
2. Verify user balance >= `token_amount`
3. Calculate APT payout using `calculate_sale_return_bancor`
4. Assert `apt_out >= min_apt_out`
5. Assert `current_timestamp <= deadline`
6. Burn tokens from user
7. Transfer APT from pool to user
8. Emit `SellEvent`

---

#### 4. `set_admin`
```move
public entry fun set_admin(
    sender: &signer,
    new_admin: address
) acquires Config
```
**Description**: Admin transfers admin rights immediately (no pending state).

**Logic**:
1. Assert sender is current admin
2. Set `config.admin_addr = new_admin`
3. Emit `AdminChangedEvent`

---

#### 5. `set_treasury`
```move
public entry fun set_treasury(
    sender: &signer,
    new_treasury: address
) acquires Config
```
**Description**: Admin sets treasury address for fee collection.

**Logic**:
1. Assert sender is admin
2. Set `config.treasury_addr = new_treasury`
3. Emit `TreasuryChangedEvent`

---

#### 6. `transfer_to_admin`
```move
public entry fun transfer_to_admin(
    sender: &signer,
    pool_id: Object<Metadata>,
    amount: u64
) acquires Config, LiquidityPool, ResourceAccountCapability
```
**Description**: Admin withdraws APT from a specific pool (emergency or fee collection).

**Logic**:
1. Assert sender is admin
2. Verify pool exists and has sufficient balance
3. Transfer APT from pool to admin
4. Emit `AdminWithdrawalEvent`

**Note**: Should be used carefully; consider restrictions or time-locks.

---

#### 7. `update_fee`
```move
public entry fun update_fee(
    sender: &signer,
    buy_fee_bps: u64,  // basis points (100 = 1%)
    sell_fee_bps: u64
) acquires Config, FeeConfig
```
**Description**: Admin updates global or per-pool trading fees.

**Logic**:
1. Assert sender is admin
2. Assert fees are within acceptable range (e.g., max 10% = 1000 bps)
3. Update `FeeConfig { buy_fee_bps, sell_fee_bps }`
4. Emit `FeeUpdatedEvent`

---

#### 8. `update_pool_settings`
```move
public entry fun update_pool_settings(
    sender: &signer,
    pool_id: Object<Metadata>,
    market_cap_threshold_usd: Option<u64>,
    enable_trading: Option<bool>
) acquires Config, PoolSettings
```
**Description**: Admin updates pool-specific settings.

**Logic**:
1. Assert sender is admin
2. If `market_cap_threshold_usd.is_some()`, update threshold
3. If `enable_trading.is_some()`, enable/disable trading (emergency pause)
4. Emit `PoolSettingsUpdatedEvent`

---

### Read Functions

#### Price & Supply Functions

##### 1. `get_current_price`
```move
#[view]
public fun get_current_price(pool_id: Object<Metadata>): u64
```
Returns current price per token in APT (smallest units).

---

##### 2. `get_current_price_u256`
```move
#[view]
public fun get_current_price_u256(pool_id: Object<Metadata>): u256
```
Returns current price with higher precision using u256.

---

##### 3. `get_current_supply`
```move
#[view]
public fun get_current_supply(pool_id: Object<Metadata>): u128
```
Returns current circulating supply.

---

#### Calculation Functions

##### 4. `calculate_curved_mint_return`
```move
#[view]
public fun calculate_curved_mint_return(
    pool_id: Object<Metadata>,
    apt_amount: u64
): u64
```
Calculates tokens received for given APT amount (before fees).

---

##### 5. `calculate_curved_burn_return`
```move
#[view]
public fun calculate_curved_burn_return(
    pool_id: Object<Metadata>,
    token_amount: u64
): u64
```
Calculates APT received for given token amount (before fees).

---

##### 6. `calculate_purchance_return_bancor`
```move
#[view]
public fun calculate_purchance_return_bancor(
    supply: u128,
    reserve_balance: u64,
    reserve_ratio: u64,
    deposit_amount: u64
): u64
```
Pure Bancor purchase calculation.

**Formula**:
```
return = supply * ((1 + deposit / balance) ^ (reserve_ratio / 100) - 1)
```

---

##### 7. `calculate_sale_return_bancor`
```move
#[view]
public fun calculate_sale_return_bancor(
    supply: u128,
    reserve_balance: u64,
    reserve_ratio: u64,
    sell_amount: u64
): u64
```
Pure Bancor sale calculation.

**Formula**:
```
return = balance * (1 - (1 - amount / supply) ^ (100 / reserve_ratio))
```

---

#### Pool & Configuration Getters

##### 8. `get_pool`
```move
#[view]
public fun get_pool(pool_id: Object<Metadata>): PoolInfo
```
Returns comprehensive pool information struct.

```move
struct PoolInfo has copy, drop {
    metadata: TokenMetadata,
    curve: BancorCurve,
    settings: PoolSettings,
    current_supply: u128,
    reserve_balance: u64,
    market_cap_usd: u64
}
```

---

##### 9. `get_pools`
```move
#[view]
public fun get_pools(): vector<Object<Metadata>>
```
Returns all pool IDs from registry.

---

##### 10. `get_tokens`
```move
#[view]
public fun get_tokens(): vector<TokenMetadata>
```
Returns metadata for all tokens.

---

##### 11. `get_pool_balance`
```move
#[view]
public fun get_pool_balance(pool_id: Object<Metadata>): u64
```
Returns APT reserve balance for a pool.

---

##### 12. `get_curve_data`
```move
#[view]
public fun get_curve_data(pool_id: Object<Metadata>): BancorCurve
```
Returns bonding curve parameters (reserve ratio, reserve balance).

---

##### 13. `get_fees`
```move
#[view]
public fun get_fees(): (u64, u64)
```
Returns `(buy_fee_bps, sell_fee_bps)`.

---

##### 14. `get_admin`
```move
#[view]
public fun get_admin(): address
```
Returns current admin address.

---

##### 15. `get_treasury`
```move
#[view]
public fun get_treasury(): address
```
Returns treasury address for fee collection.

---

##### 16. `calculate_pool_settings`
```move
#[view]
public fun calculate_pool_settings(pool_id: Object<Metadata>): PoolSettings
```
Returns pool settings including migration status.

---

##### 17. `get_max_left_apt_in_pool`
```move
#[view]
public fun get_max_left_apt_in_pool(pool_id: Object<Metadata>): u64
```
Calculates maximum APT that can be withdrawn if all tokens are sold (before fees).

---

##### 18. `get_max_left_apt_in_pool_including_fee`
```move
#[view]
public fun get_max_left_apt_in_pool(pool_id: Object<Metadata>): u64
```
Calculates maximum APT that can be withdrawn if all tokens are sold (after fees).

---

## Data Structures

### Core Structs

```move
struct BancorCurve has key, store, copy, drop {
    reserve_ratio: u64,        // 1-100 (connector weight)
    reserve_balance: u64,      // APT in pool
    is_active: bool
}

struct FeeConfig has key {
    buy_fee_bps: u64,          // basis points (100 = 1%)
    sell_fee_bps: u64,
    treasury_addr: address
}

struct Pool has key {
    fa_controller: FAController,
    metadata: TokenMetadata,
    curve: BancorCurve,
    settings: PoolSettings,
    created_at: u64,
    creator: address
}
```

---

## Events

### New Events

```move
#[event]
struct CreatePoolEvent has store, drop {
    pool_id: Object<Metadata>,
    creator: address,
    name: String,
    ticker: String,
    reserve_ratio: u64,
    initial_reserve: u64,
    timestamp: u64
}

#[event]
struct BuyEvent has store, drop {
    pool_id: Object<Metadata>,
    buyer: address,
    apt_spent: u64,
    tokens_received: u64,
    fee_collected: u64,
    new_price: u64,
    timestamp: u64
}

#[event]
struct SellEvent has store, drop {
    pool_id: Object<Metadata>,
    seller: address,
    tokens_sold: u64,
    apt_received: u64,
    fee_collected: u64,
    new_price: u64,
    timestamp: u64
}

#[event]
struct LiquidityMigratedEvent has store, drop {
    pool_id: Object<Metadata>,
    hyperion_pool_address: address,
    apt_liquidity: u64,
    token_liquidity: u64,
    market_cap_usd: u64,
    timestamp: u64
}

#[event]
struct AdminChangedEvent has store, drop {
    old_admin: address,
    new_admin: address,
    timestamp: u64
}

#[event]
struct TreasuryChangedEvent has store, drop {
    old_treasury: address,
    new_treasury: address,
    timestamp: u64
}

#[event]
struct FeeUpdatedEvent has store, drop {
    old_buy_fee_bps: u64,
    new_buy_fee_bps: u64,
    old_sell_fee_bps: u64,
    new_sell_fee_bps: u64,
    timestamp: u64
}

#[event]
struct PoolSettingsUpdatedEvent has store, drop {
    pool_id: Object<Metadata>,
    market_cap_threshold_usd: u64,
    trading_enabled: bool,
    timestamp: u64
}

#[event]
struct AdminWithdrawalEvent has store, drop {
    pool_id: Object<Metadata>,
    admin: address,
    amount: u64,
    timestamp: u64
}
```

---

## Error Codes

Add new error constants:

```move
const EINVALID_RESERVE_RATIO: u64 = 100;
const EINVALID_TICKER_LENGTH: u64 = 101;
const ESLIPPAGE_EXCEEDED: u64 = 102;
const EDEADLINE_PASSED: u64 = 103;
const ETRADING_DISABLED: u64 = 104;
const EMIGRATION_COMPLETED: u64 = 105;
const EFEE_TOO_HIGH: u64 = 106;
const EINSUFFICIENT_RESERVE: u64 = 107;
const EZERO_SUPPLY: u64 = 108;
const EINVALID_AMOUNT: u64 = 109;
const EPOOL_NOT_FOUND: u64 = 110;
```

---

## Hyperion DEX Integration

### Requirements
- **Hyperion Contract Address**: Obtain from Hyperion documentation
- **Function Calls**:
  - `hyperion::pool::create_pool<CoinType>(...)` or equivalent
  - `hyperion::liquidity::add_liquidity<CoinType>(...)`

### Migration Logic

```move
fun migrate_to_hyperion(pool_id: Object<Metadata>) 
    acquires Pool, BancorCurve, PoolSettings, ResourceAccountCapability {
    
    let pool = borrow_global_mut<Pool>(object::object_address(&pool_id));
    let curve = borrow_global_mut<BancorCurve>(object::object_address(&pool_id));
    let settings = borrow_global_mut<PoolSettings>(object::object_address(&pool_id));
    
    // Deactivate bonding curve
    curve.is_active = false;
    
    // Calculate liquidity amounts
    let apt_liquidity = curve.reserve_balance;
    let token_supply = fungible_asset::supply(pool_id);
    let token_liquidity = calculate_tokens_for_liquidity(token_supply, apt_liquidity);
    
    // Mint tokens for liquidity
    let liquidity_tokens = mint_internal(pool_id, token_liquidity);
    
    // Call Hyperion DEX
    let hyperion_pool = hyperion::create_and_add_liquidity(
        pool_id,
        apt_liquidity,
        liquidity_tokens
    );
    
    // Update settings
    settings.hyperion_pool_address = option::some(hyperion_pool);
    settings.migration_completed = true;
    settings.migration_timestamp = option::some(timestamp::now_seconds());
    
    // Emit event
    event::emit(LiquidityMigratedEvent { ... });
}
```

---

## Price Oracle Integration

### APT/USD Price Feed
- **Source**: Use Pyth Network, Switchboard, or similar oracle
- **Update Frequency**: Real-time or cached (max 5 minutes stale)
- **Fallback**: Admin-set emergency price

### Implementation
```move
struct PriceOracle has key {
    apt_usd_price: u64,       // in cents (e.g., 850 = $8.50)
    last_update: u64,
    oracle_address: address
}

fun get_market_cap_usd(pool_id: Object<Metadata>): u64 
    acquires Pool, BancorCurve, PriceOracle {
    
    let supply = fungible_asset::supply(pool_id);
    let price_apt = get_current_price(pool_id);
    let oracle = borrow_global<PriceOracle>(@blaze_token_launchpad);
    
    // market_cap = supply * price_per_token * apt_usd_price
    // Careful with decimals and overflow
    let market_cap = calculate_market_cap(supply, price_apt, oracle.apt_usd_price);
    market_cap
}
```

---

## Security Considerations

### 1. Overflow Protection
- Use u128/u256 for intermediate calculations
- Add safe math wrappers for multiplication/division
- Test edge cases with max values

### 2. Slippage Protection
- Require `min_tokens_out` / `min_apt_out` parameters
- Enforce deadlines to prevent stale transactions
- Consider max slippage percentage (e.g., 5%)

### 3. Reentrancy Guards
- Move doesn't allow reentrancy by default, but be cautious with cross-contract calls
- Ensure state updates happen before external calls

### 4. Admin Controls
- Implement time-locks for critical admin functions
- Consider multi-sig for admin role
- Emit events for all admin actions

### 5. Fee Limits
- Cap fees at reasonable maximum (e.g., 10%)
- Prevent fee changes from affecting in-flight transactions

### 6. Migration Safety
- Make migration irreversible
- Ensure all calculations are correct before migration
- Test migration extensively on devnet/testnet

---

## Testing Requirements

### Unit Tests
- [ ] Token creation with all metadata fields
- [ ] Bancor purchase calculation accuracy
- [ ] Bancor sale calculation accuracy
- [ ] Fee calculation and collection
- [ ] Slippage protection enforcement
- [ ] Deadline enforcement
- [ ] Market cap calculation
- [ ] Migration trigger at threshold
- [ ] Admin function access control
- [ ] Pool settings updates

### Integration Tests
- [ ] Full buy flow with fees
- [ ] Full sell flow with fees
- [ ] Create pool → buy → sell cycle
- [ ] Market cap threshold → migration flow
- [ ] Hyperion DEX interaction (mock or testnet)
- [ ] Price oracle integration
- [ ] Multiple pools operating simultaneously

### Edge Cases
- [ ] Zero supply purchase
- [ ] Sell entire supply
- [ ] Maximum value overflow tests
- [ ] Minimum trade amounts
- [ ] Concurrent transactions
- [ ] Migration race conditions

---

## Migration Path (V1 → V2)

### Option 1: Deploy New Contract
- Deploy V2 as separate module
- Migrate liquidity manually or via script
- Sunset V1 gradually

### Option 2: Upgrade Existing Contract
- Use Aptos package upgrades
- Ensure backward compatibility
- Migrate existing pools to new data structures

**Recommended**: Option 1 for cleaner separation and reduced risk.

---

## UI/UX Considerations

### Token Creation Form
- Image upload with preview
- Character limits with counters
- Social link validation (URL format)
- Market cap threshold selector
- Reserve ratio slider (with explanation)

### Trading Interface
- Real-time price chart
- Market cap progress bar (to $75,000)
- Slippage tolerance setting
- Transaction preview with fees
- Post-migration notification

### Pool Details Page
- Token metadata display (image, description, social links)
- Current price, supply, market cap
- Bonding curve visualization
- Transaction history
- Migration status indicator

---

## Implementation Phases

### Phase 1: Core Bancor Implementation (2-3 weeks)
- [ ] Implement Bancor formula functions
- [ ] Update buy/sell logic
- [ ] Add fee structure
- [ ] Write unit tests

### Phase 2: Enhanced Metadata (1 week)
- [ ] Add TokenMetadata struct
- [ ] Update create_pool function
- [ ] Add social link validation
- [ ] Update events

### Phase 3: Market Cap & Migration (2 weeks)
- [ ] Integrate price oracle
- [ ] Implement market cap calculation
- [ ] Build Hyperion DEX integration
- [ ] Test migration flow

### Phase 4: Admin Functions (1 week)
- [ ] Implement all admin write functions
- [ ] Add access control checks
- [ ] Add admin events
- [ ] Test admin workflows

### Phase 5: Testing & Audit (2-3 weeks)
- [ ] Comprehensive test suite
- [ ] Devnet deployment and testing
- [ ] Security audit
- [ ] Bug fixes and optimizations

### Phase 6: Deployment (1 week)
- [ ] Testnet deployment
- [ ] Documentation finalization
- [ ] Mainnet deployment
- [ ] Monitoring and support

**Total Estimated Timeline**: 9-12 weeks

---

## Success Metrics

### Technical Metrics
- Zero critical vulnerabilities in audit
- >95% test coverage
- Gas costs within acceptable range (<0.1 APT per transaction)
- Sub-second transaction confirmation

### Product Metrics
- Number of pools created
- Total value locked (TVL)
- Number of successful migrations to Hyperion
- Trading volume
- User retention rate

---

## Open Questions

1. **Hyperion DEX API**: Need confirmation on exact function signatures and integration pattern
2. **Price Oracle**: Which oracle should we use? Pyth vs. Switchboard vs. custom
3. **Initial Reserve**: Should there be a minimum initial APT reserve for pool creation?
4. **Fee Recipient**: Should fees go to treasury or stay in pool?
5. **Migration Tokens**: How many tokens should be reserved for Hyperion liquidity vs. kept in bonding curve?
6. **Admin Powers**: Should admin be able to force-migrate a pool before threshold?

---

## Dependencies

### External
- Hyperion DEX SDK/contracts
- Price oracle (Pyth/Switchboard)
- Aptos framework (latest version)

### Internal
- Current launchpad.move module (for reference)
- Test utilities
- Deployment scripts

---

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Bancor formula overflow | High | Medium | Use u256, add bounds checks |
| Incorrect market cap calculation | High | Low | Extensive testing, oracle redundancy |
| Hyperion integration failure | High | Medium | Mock testing, fallback mechanism |
| Price oracle manipulation | High | Low | Use multiple oracles, circuit breakers |
| Admin key compromise | High | Low | Multi-sig, time-locks |
| Migration liquidity loss | High | Low | Audit, testnet validation |

---

## Appendix

### A. Bancor Formula Deep Dive

The Bancor Protocol uses a Constant Reserve Ratio (CRR) model:

**Key Variables:**
- `S` = Token supply
- `R` = Reserve balance (APT)
- `CRR` = Connector weight (reserve ratio) as percentage

**Price Formula:**
```
Price = R / (S * CRR)
```

**Purchase Return (continuous):**
```
ΔS = S * ((1 + ΔR/R)^CRR - 1)
```

**Sale Return (continuous):**
```
ΔR = R * (1 - (1 - ΔS/S)^(1/CRR))
```

### B. Example Calculations

**Scenario**: Pool with 1M tokens, 10,000 APT reserve, 50% reserve ratio

**Buy 100 APT:**
```
ΔS = 1,000,000 * ((1 + 100/10,000)^0.5 - 1)
   = 1,000,000 * (1.01^0.5 - 1)
   = 1,000,000 * (1.00498756 - 1)
   = 4,987.56 tokens
```

**Sell 5,000 tokens:**
```
ΔR = 10,000 * (1 - (1 - 5000/1,000,000)^2)
   = 10,000 * (1 - 0.995^2)
   = 10,000 * (1 - 0.990025)
   = 99.75 APT
```

### C. References

- [Bancor Protocol Whitepaper](https://about.bancor.network/protocol/)
- [Bonding Curves Explained - Yos Riady](https://yos.io/2018/11/10/bonding-curves/)
- [Hyperion DEX Documentation](#) (TBD)
- [Pyth Network Aptos Integration](https://docs.pyth.network/price-feeds/use-real-time-data/aptos)
- [Aptos Fungible Asset Standard](https://aptos.dev/standards/fungible-asset/)

---

## Approval

**Product Owner:** ________________  Date: __________

**Tech Lead:** ________________  Date: __________

**Security Lead:** ________________  Date: __________

---

*End of PRD*
