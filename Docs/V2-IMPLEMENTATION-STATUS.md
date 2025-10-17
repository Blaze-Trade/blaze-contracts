# Launchpad V2 - Implementation Status

**Created:** October 13, 2025  
**Contract:** `move/sources/launchpad_v2.move`  
**Status:** Core features implemented, pending Hyperion integration

---

## ✅ Completed Features

### 1. Enhanced Token Metadata
- ✅ Full token metadata support (name, ticker, image URI, description)
- ✅ Social links struct (website, Twitter, Telegram, Discord)
- ✅ Creator tracking and creation timestamp
- ✅ All metadata stored in `TokenMetadata` struct

### 2. Bancor Bonding Curve
- ✅ Bancor formula implementation with reserve ratio (1-100%)
- ✅ Purchase formula: `ΔS = S * ((1 + ΔR/R)^(CRR/100) - 1)`
- ✅ Sale formula: `ΔR = R * (1 - (1 - ΔS/S)^(100/CRR))`
- ✅ Fixed-point arithmetic with PRECISION = 1e8
- ✅ Fractional power approximation for curve calculations
- ✅ Bootstrap case handling for initial purchases

### 3. Core Data Structures
```move
struct TokenMetadata     // Full metadata with social links
struct SocialLinks       // Website, Twitter, Telegram, Discord
struct BancorCurve      // Reserve ratio, balance, active status
struct PoolSettings     // Market cap threshold, migration status
struct FeeConfig        // Buy/sell fees in basis points
struct Pool             // Complete pool data
struct Registry         // All pool registry
struct Config           // Admin and treasury addresses
```

### 4. Write Functions (10/10 Complete)

#### ✅ `create_pool`
- Create token pool with full metadata
- Configurable reserve ratio (1-100%)
- Initial APT reserve requirement
- Optional market cap threshold
- Social links integration
- Event emission

#### ✅ `buy`
- Purchase tokens via Bancor curve
- Slippage protection (`min_tokens_out`)
- Deadline enforcement
- Fee calculation and treasury payment
- Reserve balance updates
- Liquidity tracking
- **Market cap check and automatic migration trigger**
- Event emission with price/supply data

#### ✅ `sell`
- Sell tokens for APT
- Slippage protection (`min_apt_out`)
- Deadline enforcement
- User balance verification
- Fee calculation
- Burn tokens and payout APT
- Event emission

#### ✅ `set_admin`
- Immediate admin transfer
- Event emission

#### ✅ `set_treasury`
- Update treasury address for fee collection
- Updates both Config and FeeConfig
- Event emission

#### ✅ `update_fee`
- Set buy and sell fees (basis points)
- Max fee validation (10% cap)
- Event emission

#### ✅ `update_pool_settings`
- Admin can adjust market cap threshold
- Enable/disable trading (emergency pause)
- Event emission

#### ✅ `transfer_to_admin`
- Emergency withdrawal function
- Updates reserve balance
- Event emission

#### ✅ `update_oracle_price`
- Admin-only function to update APT/USD price
- Updates oracle timestamp
- Validates price > 0
- Event emission

#### ✅ `force_migrate_to_hyperion`
- Admin function to manually trigger migration
- Bypasses market cap threshold check
- Calls internal migration function

### 5. View Functions (22/22 Complete)

#### Price & Supply Functions
- ✅ `get_current_price` - Returns price in APT (u64)
- ✅ `get_current_price_u256` - High precision price
- ✅ `get_current_supply` - Current token supply

#### Calculation Functions
- ✅ `calculate_curved_mint_return` - Tokens for APT (before fees)
- ✅ `calculate_curved_burn_return` - APT for tokens (before fees)
- ✅ `calculate_purchance_return_bancor` - Pure Bancor purchase
- ✅ `calculate_sale_return_bancor` - Pure Bancor sale

#### Pool & Configuration Getters
- ✅ `get_pool` - Returns (TokenMetadata, BancorCurve, PoolSettings)
- ✅ `get_pools` - All pool IDs
- ✅ `get_tokens` - All token metadata
- ✅ `get_pool_balance` - APT reserve balance
- ✅ `get_curve_data` - Bancor curve parameters
- ✅ `get_fees` - (buy_fee_bps, sell_fee_bps)
- ✅ `get_admin` - Admin address
- ✅ `get_treasury` - Treasury address
- ✅ `calculate_pool_settings` - Pool settings struct
- ✅ `get_max_left_apt_in_pool` - Max APT withdrawal (before fees)
- ✅ `get_max_left_apt_in_pool_including_fee` - Max APT (after fees)
- ✅ `get_resource_account_address` - Resource account address

#### Oracle & Market Cap Functions
- ✅ `get_apt_usd_price` - Current APT/USD price in cents
- ✅ `get_oracle_data` - Returns (price, last_update, oracle_address)
- ✅ `calculate_market_cap_usd` - Pool market cap in USD cents
- ✅ `is_migration_threshold_reached` - Check if pool ready for migration

### 6. Events (10/10 Complete)
- ✅ `CreatePoolEvent`
- ✅ `BuyEvent`
- ✅ `SellEvent`
- ✅ `LiquidityMigratedEvent` (now emitted on migration)
- ✅ `AdminChangedEvent`
- ✅ `TreasuryChangedEvent`
- ✅ `FeeUpdatedEvent`
- ✅ `PoolSettingsUpdatedEvent`
- ✅ `AdminWithdrawalEvent`
- ✅ `OraclePriceUpdatedEvent`

### 7. Security Features
- ✅ Slippage protection (min_tokens_out, min_apt_out)
- ✅ Deadline enforcement to prevent stale transactions
- ✅ Fee caps (max 10%)
- ✅ Admin-only functions with assertions
- ✅ Balance and reserve checks
- ✅ Trading enable/disable mechanism

### 8. Market Cap Calculation & Hyperion Migration ✅
- ✅ Price oracle integration (PriceOracle struct with APT/USD price)
- ✅ Market cap calculation function (`calculate_market_cap_usd`)
- ✅ Automatic migration trigger in `buy` function
- ✅ Migration helper function (`migrate_to_hyperion_internal`)
- ✅ Admin functions: `update_oracle_price`, `force_migrate_to_hyperion`
- ✅ View functions: `get_apt_usd_price`, `get_oracle_data`, `is_migration_threshold_reached`
- ⚠️ **Note:** Hyperion DEX integration uses placeholder - requires actual DEX contract addresses

---

## 🔄 Pending Implementation

### 1. Hyperion DEX Contract Integration
**Priority:** High  
**Status:** Infrastructure complete, awaiting DEX contract details

**Completed:**
- ✅ Price oracle struct with APT/USD price tracking
- ✅ Market cap calculation (`calculate_market_cap_internal`, `calculate_market_cap_usd`)
- ✅ Migration framework (`migrate_to_hyperion_internal`)
- ✅ Automatic trigger in `buy` function when threshold reached
- ✅ Admin functions for oracle updates and manual migration
- ✅ View functions for monitoring market cap and migration status

**Remaining:**
- [ ] Integrate actual Hyperion DEX contract calls in `migrate_to_hyperion_internal`
- [ ] Replace placeholder `@0x0` with real Hyperion pool address
- [ ] Add proper liquidity transfer logic to Hyperion
- [ ] Test migration flow with Hyperion on devnet

**Required Information:**
- Hyperion DEX contract address
- Hyperion pool creation function signature
- Hyperion liquidity addition function signature

**Integration Example (to be implemented):**
```move
// In migrate_to_hyperion_internal():
let hyperion_pool_addr = hyperion::pool::create_pool<FA>(
    pool_id, 
    apt_liquidity, 
    token_liquidity
);
hyperion::liquidity::add_liquidity(hyperion_pool_addr, ...);
pool.settings.hyperion_pool_address = option::some(hyperion_pool_addr);
```

### 2. Testing Suite
**Priority:** High  
**Status:** Not started

**Required Tests:**
- [ ] Pool creation with various reserve ratios
- [ ] Bancor purchase calculations at different supply levels
- [ ] Bancor sale calculations
- [ ] Fee collection and treasury payments
- [ ] Slippage protection enforcement
- [ ] Deadline enforcement
- [ ] Admin function access control
- [ ] Emergency trading disable
- [ ] Edge cases (zero supply, max values)
- [ ] Market cap calculation with different APT prices
- [ ] Oracle price updates
- [ ] Automatic migration trigger when threshold reached
- [ ] Manual migration via `force_migrate_to_hyperion`
- [ ] Migration prevents further bonding curve trades
- [ ] View functions for oracle and market cap data

### 3. Documentation
**Priority:** Medium  
**Status:** PRD complete, implementation docs pending

**Needed:**
- [ ] API documentation for each function
- [ ] Integration guide for frontends
- [ ] Deployment guide
- [ ] Migration guide from V1 to V2

---

## 📋 Technical Notes

### Bancor Formula Implementation
The current implementation uses a **linear approximation** for fractional powers in `power_fraction()`. This is suitable for small changes but may need refinement for production:

```move
// Current: Linear approximation
fun power_fraction(base: u128, numerator: u64, denominator: u64): u128 {
    // Linear approximation: (base - 1) * (num/denom) + 1
    // Works well for reserve ratios but could be improved
}
```

**Future Improvement:** Consider implementing Taylor series expansion or Newton's method for more accurate fractional exponentiation.

### Fixed-Point Precision
- Uses `PRECISION = 1e8` for calculations
- All intermediate calculations use u128 to prevent overflow
- Final results downcast to u64 where appropriate

### Resource Account
- Created in `init_module` with seed `"liquidity_pool_v2"`
- Holds all APT reserves for all pools
- Capability stored in `ResourceAccountCapability`

### Gas Optimization Opportunities
1. **Batch operations** - Could add batch buy/sell for multiple pools
2. **View function caching** - Consider caching frequently accessed data
3. **Power calculation** - Optimize `power_fraction` with lookup tables for common ratios

---

## 🚀 Deployment Checklist

Before deploying to mainnet:

- [ ] Complete Hyperion DEX integration
- [ ] Integrate price oracle (Pyth/Switchboard)
- [ ] Comprehensive test suite passing
- [ ] Security audit completed
- [ ] Gas optimization review
- [ ] Frontend integration tested on devnet
- [ ] Admin multi-sig setup
- [ ] Fee parameters finalized
- [ ] Emergency pause procedures documented
- [ ] Monitoring and alerting configured

---

## 📊 Comparison: V1 vs V2

| Feature | V1 | V2 |
|---------|----|----|
| Bonding Curve | Quadratic | Bancor (configurable ratio) |
| Metadata | Basic (name, symbol, decimals) | Full (+ image, description, social links) |
| Fees | Fixed per-unit | Percentage-based with treasury |
| Admin Control | Set pending admin | Direct admin + treasury management |
| Slippage Protection | No | Yes (min_out + deadline) |
| Price Formula | `supply^2 / virtual_liquidity` | Bancor `R / (S * CRR)` |
| DEX Integration | Manual | Automatic at threshold |
| Per-Pool Settings | Global | Configurable per pool |
| Emergency Controls | None | Trading pause, admin withdrawal |

---

## 🔗 Integration Guide (Preliminary)

### Creating a Pool
```typescript
// Example transaction payload
{
  function: "0x...::launchpad_v2::create_pool",
  type_arguments: [],
  arguments: [
    "My Token",                    // name
    "MTK",                          // ticker
    "ipfs://...",                   // token_image_uri
    "A great token",                // description (optional)
    "https://mytoken.com",         // website (optional)
    "@mytoken",                     // twitter (optional)
    "t.me/mytoken",                 // telegram (optional)
    "discord.gg/mytoken",           // discord (optional)
    "1000000000000",                // max_supply (optional)
    8,                              // decimals
    50,                             // reserve_ratio (50%)
    "100000000",                    // initial_apt_reserve (1 APT)
    "7500000"                       // market_cap_threshold_usd ($75k)
  ]
}
```

### Buying Tokens
```typescript
{
  function: "0x...::launchpad_v2::buy",
  type_arguments: [],
  arguments: [
    pool_id,         // Object<Metadata>
    "10000000",      // apt_amount (0.1 APT)
    "950",           // min_tokens_out (slippage tolerance)
    Math.floor(Date.now()/1000) + 300  // deadline (5 min)
  ]
}
```

---

## 🎯 Next Steps

1. **Immediate:**
   - ✅ ~~Implement `calculate_market_cap_usd` function~~ (COMPLETED)
   - ✅ ~~Implement `migrate_to_hyperion` function~~ (COMPLETED)
   - Get Hyperion DEX contract addresses and API documentation
   - Integrate actual Hyperion DEX calls in migration function
   - Integrate real-time price oracle (Pyth Network or Switchboard)

2. **Short-term:**
   - Write comprehensive test suite (including migration tests)
   - Test migration flow with Hyperion on devnet
   - Deploy to devnet for testing
   - Security audit engagement
   - Frontend integration testing

3. **Medium-term:**
   - Mainnet deployment
   - User documentation
   - Marketing materials integration
   - Monitoring dashboards with market cap tracking

---

## 📞 Contact & Support

For questions or issues with the V2 implementation:
- Review the PRD: `Docs/PRD-launchpad-v2.md`
- Check existing contract: `move/sources/launchpad.move` (V1)
- New contract: `move/sources/launchpad_v2.move`

---

*Last Updated: October 17, 2025*

## Summary of Recent Updates (Oct 17, 2025)

**Market Cap Calculation & Hyperion Migration - IMPLEMENTED** ✅

Added complete infrastructure for market cap tracking and automated DEX migration:
- Oracle price management with `PriceOracle` struct
- Market cap calculation functions using APT/USD price
- Automatic migration trigger in `buy()` when threshold reached
- Admin functions: `update_oracle_price`, `force_migrate_to_hyperion`
- View functions: `get_apt_usd_price`, `get_oracle_data`, `calculate_market_cap_usd`, `is_migration_threshold_reached`
- New event: `OraclePriceUpdatedEvent`

**Status:** Ready for Hyperion DEX contract integration once addresses available.
