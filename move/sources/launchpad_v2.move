module blaze_token_launchpad::launchpad_v2 {
    use std::option::{Self, Option};
    use std::signer;
    use std::string::String;
    use std::vector;

    use aptos_std::table::Table;

    #[test_only]
    use std::string;
    #[test_only]
    use aptos_framework::coin;
    #[test_only]
    use aptos_framework::aptos_coin;

    use aptos_framework::aptos_account;
    use aptos_framework::event;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::timestamp;

    // ================================= Error Constants ================================= //

    /// Only admin can perform this action
    const EONLY_ADMIN: u64 = 1;
    /// Invalid reserve ratio (must be 1-100)
    const EINVALID_RESERVE_RATIO: u64 = 100;
    /// Invalid ticker length (must be 1-10 characters)
    const EINVALID_TICKER_LENGTH: u64 = 101;
    /// Slippage tolerance exceeded
    const ESLIPPAGE_EXCEEDED: u64 = 102;
    /// Transaction deadline has passed
    const EDEADLINE_PASSED: u64 = 103;
    /// Trading is disabled for this pool
    const ETRADING_DISABLED: u64 = 104;
    /// Migration to DEX already completed
    const EMIGRATION_COMPLETED: u64 = 105;
    /// Fee too high (exceeds maximum)
    const EFEE_TOO_HIGH: u64 = 106;
    /// Insufficient reserve balance
    const EINSUFFICIENT_RESERVE: u64 = 107;
    /// Supply is zero
    const EZERO_SUPPLY: u64 = 108;
    /// Invalid amount (must be > 0)
    const EINVALID_AMOUNT: u64 = 109;
    /// Pool not found
    const EPOOL_NOT_FOUND: u64 = 110;
    /// Insufficient balance
    const EINSUFFICIENT_BALANCE: u64 = 111;
    /// Resource account not initialized
    const ERESOURCE_ACCOUNT_NOT_INITIALIZED: u64 = 112;
    /// Insufficient liquidity for payout
    const EINSUFFICIENT_LIQUIDITY: u64 = 113;
    /// Invalid initial reserve (must be > 0)
    const EINVALID_INITIAL_RESERVE: u64 = 114;

    // ================================= Constants ================================= //

    /// Maximum fee in basis points (10% = 1000 bps)
    const MAX_FEE_BPS: u64 = 1000;
    /// Default market cap threshold in USD cents ($75,000 = 7,500,000 cents)
    const DEFAULT_MARKET_CAP_THRESHOLD_USD: u64 = 7500000;
    /// Basis points divisor (10000 = 100%)
    const BPS_DIVISOR: u64 = 10000;
    /// Fixed point precision for calculations (1e8)
    const PRECISION: u128 = 100000000;

    // ================================= Data Structures ================================= //

    /// Social media links for a token
    struct SocialLinks has store, copy, drop {
        website: Option<String>,
        twitter: Option<String>,
        telegram: Option<String>,
        discord: Option<String>
    }

    /// Complete token metadata
    struct TokenMetadata has store, copy, drop {
        name: String,
        ticker: String,
        token_image_uri: String,
        description: Option<String>,
        social_links: SocialLinks,
        created_at: u64,
        creator: address
    }

    /// Bancor bonding curve parameters
    struct BancorCurve has store, copy, drop {
        reserve_ratio: u64,        // 1-100 (connector weight as percentage)
        reserve_balance: u64,      // APT in pool
        is_active: bool
    }

    /// Pool-specific settings
    struct PoolSettings has store, copy, drop {
        market_cap_threshold_usd: u64,      // in cents
        hyperion_pool_address: Option<address>,
        migration_completed: bool,
        migration_timestamp: Option<u64>,
        trading_enabled: bool
    }

    /// Fee configuration
    struct FeeConfig has key {
        buy_fee_bps: u64,          // basis points (100 = 1%)
        sell_fee_bps: u64,
        treasury_addr: address
    }

    /// FA controller capabilities (per pool)
    struct FAController has key {
        mint_ref: fungible_asset::MintRef,
        burn_ref: fungible_asset::BurnRef,
        transfer_ref: fungible_asset::TransferRef
    }

    /// Complete pool data (stored at FA object address)
    struct Pool has key {
        metadata: TokenMetadata,
        curve: BancorCurve,
        settings: PoolSettings
    }

    /// Global registry of all pools
    struct Registry has key {
        pools: vector<Object<Metadata>>
    }

    /// Global configuration
    struct Config has key {
        admin_addr: address,
        treasury_addr: address
    }

    /// Liquidity tracking (global for all pools)
    struct LiquidityPool has key {
        total_apt_collected: u64,
        total_apt_paid_out: u64
    }

    /// Resource account signer capability
    struct ResourceAccountCapability has key {
        signer_capability: SignerCapability
    }

    /// Price oracle data (placeholder for future oracle integration)
    struct PriceOracle has key {
        apt_usd_price: u64,        // in cents (e.g., 850 = $8.50)
        last_update: u64,
        oracle_address: address
    }

    // ================================= Events ================================= //

    #[event]
    struct CreatePoolEvent has store, drop {
        pool_id: Object<Metadata>,
        creator: address,
        name: String,
        ticker: String,
        reserve_ratio: u64,
        initial_reserve: u64,
        market_cap_threshold_usd: u64,
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
        new_supply: u128,
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
        new_supply: u128,
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

    // ================================= Initialization ================================= //

    /// Initialize the module
    fun init_module(sender: &signer) {
        let sender_addr = signer::address_of(sender);
        
        move_to(sender, Registry { pools: vector::empty() });
        move_to(
            sender,
            Config {
                admin_addr: sender_addr,
                treasury_addr: sender_addr
            }
        );
        move_to(
            sender,
            FeeConfig {
                buy_fee_bps: 100,      // 1% default buy fee
                sell_fee_bps: 100,     // 1% default sell fee
                treasury_addr: sender_addr
            }
        );
        move_to(
            sender,
            LiquidityPool {
                total_apt_collected: 0,
                total_apt_paid_out: 0
            }
        );
        
        // Initialize resource account for liquidity management
        let (_resource_account, signer_cap) = account::create_resource_account(sender, b"liquidity_pool_v2");
        move_to(sender, ResourceAccountCapability { signer_capability: signer_cap });

        // Initialize price oracle with placeholder values (to be updated via oracle integration)
        move_to(
            sender,
            PriceOracle {
                apt_usd_price: 850,    // $8.50 default
                last_update: timestamp::now_seconds(),
                oracle_address: sender_addr
            }
        );
    }

    // ================================= Helper Functions ================================= //

    /// Check if sender is admin
    fun is_admin(sender_addr: address): bool acquires Config {
        let config = borrow_global<Config>(@blaze_token_launchpad);
        sender_addr == config.admin_addr
    }

    /// Assert sender is admin
    fun assert_admin(sender_addr: address) acquires Config {
        assert!(is_admin(sender_addr), EONLY_ADMIN);
    }

    /// Get current timestamp
    fun now(): u64 {
        timestamp::now_seconds()
    }

    /// Calculate fee amount
    fun calculate_fee(amount: u64, fee_bps: u64): u64 {
        ((amount as u128) * (fee_bps as u128) / (BPS_DIVISOR as u128) as u64)
    }

    /// Get resource account address
    fun get_resource_account_addr(): address acquires ResourceAccountCapability {
        let cap = borrow_global<ResourceAccountCapability>(@blaze_token_launchpad);
        account::get_signer_capability_address(&cap.signer_capability)
    }

    /// Get resource account signer
    fun get_resource_account_signer(): signer acquires ResourceAccountCapability {
        let cap = borrow_global<ResourceAccountCapability>(@blaze_token_launchpad);
        account::create_signer_with_capability(&cap.signer_capability)
    }

    // ================================= Bancor Formula Functions ================================= //

    /// Calculate power using binary exponentiation for fixed-point numbers
    /// Returns base^exp with PRECISION scaling
    fun power(base: u128, exp: u64): u128 {
        if (exp == 0) {
            return PRECISION
        };
        
        let result = PRECISION;
        let current_base = base;
        let current_exp = exp;
        
        while (current_exp > 0) {
            if (current_exp % 2 == 1) {
                result = (result * current_base) / PRECISION;
            };
            current_base = (current_base * current_base) / PRECISION;
            current_exp = current_exp / 2;
        };
        
        result
    }

    /// Calculate fractional power approximation using Taylor series
    /// base^(numerator/denominator) where base is scaled by PRECISION
    fun power_fraction(base: u128, numerator: u64, denominator: u64): u128 {
        // For simplicity, using linear approximation for small exponents
        // Production version should use more sophisticated approximation
        
        if (numerator == denominator) {
            return base
        };
        
        if (numerator == 0) {
            return PRECISION
        };
        
        // Linear approximation: (base - 1) * (num/denom) + 1
        // More accurate for small changes
        if (base >= PRECISION) {
            let diff = base - PRECISION;
            PRECISION + (diff * (numerator as u128) / (denominator as u128))
        } else {
            let diff = PRECISION - base;
            PRECISION - (diff * (numerator as u128) / (denominator as u128))
        }
    }

    /// Calculate tokens received for APT deposit using Bancor formula
    /// Formula: ΔS = S * ((1 + ΔR/R)^(CRR/100) - 1)
    /// Returns tokens to mint (before fees)
    fun calculate_bancor_purchase_return(
        supply: u128,
        reserve_balance: u64,
        reserve_ratio: u64,
        deposit_amount: u64
    ): u64 {
        // Handle edge cases
        if (deposit_amount == 0) {
            return 0
        };
        
        if (supply == 0 || reserve_balance == 0) {
            // Bootstrap case: initial purchase gets tokens proportional to deposit
            // With reserve ratio as multiplier
            return ((deposit_amount as u128) * (reserve_ratio as u128) / 100 as u64)
        };

        // Calculate (1 + deposit/reserve) with PRECISION scaling
        let base = PRECISION + ((deposit_amount as u128) * PRECISION / (reserve_balance as u128));
        
        // Calculate base^(reserve_ratio/100)
        let powered = power_fraction(base, reserve_ratio, 100);
        
        // Calculate supply * (powered - 1)
        if (powered > PRECISION) {
            let multiplier = powered - PRECISION;
            ((supply * multiplier) / PRECISION as u64)
        } else {
            0
        }
    }

    /// Calculate APT received for token sale using Bancor formula
    /// Formula: ΔR = R * (1 - (1 - ΔS/S)^(100/CRR))
    /// Returns APT to return (before fees)
    fun calculate_bancor_sale_return(
        supply: u128,
        reserve_balance: u64,
        reserve_ratio: u64,
        sell_amount: u64
    ): u64 {
        // Handle edge cases
        if (sell_amount == 0 || supply == 0) {
            return 0
        };
        
        assert!(supply >= (sell_amount as u128), EINSUFFICIENT_BALANCE);
        
        // Calculate (1 - sell_amount/supply) with PRECISION scaling
        let base = PRECISION - ((sell_amount as u128) * PRECISION / supply);
        
        // Calculate base^(100/reserve_ratio)
        let powered = power_fraction(base, 100, reserve_ratio);
        
        // Calculate reserve * (1 - powered)
        if (powered < PRECISION) {
            let multiplier = PRECISION - powered;
            (((reserve_balance as u128) * multiplier) / PRECISION as u64)
        } else {
            0
        }
    }

    /// Calculate current price per token in APT
    /// Price = R / (S * CRR)
    fun calculate_current_price(
        supply: u128,
        reserve_balance: u64,
        reserve_ratio: u64
    ): u64 {
        if (supply == 0) {
            return 0
        };
        
        // Price = (reserve_balance * 100) / (supply * reserve_ratio)
        // With proper scaling
        (((reserve_balance as u128) * PRECISION * 100) / (supply * (reserve_ratio as u128)) as u64)
    }

    // ================================= Entry Functions ================================= //

    /// Create a new token pool with enhanced metadata and Bancor curve
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
    ) acquires Registry, ResourceAccountCapability {
        let sender_addr = signer::address_of(sender);
        
        // Validate inputs
        let ticker_len = std::string::length(&ticker);
        assert!(ticker_len >= 1 && ticker_len <= 10, EINVALID_TICKER_LENGTH);
        assert!(reserve_ratio >= 1 && reserve_ratio <= 100, EINVALID_RESERVE_RATIO);
        assert!(initial_apt_reserve > 0, EINVALID_INITIAL_RESERVE);
        
        // Create FA object
        let fa_obj_constructor_ref = &object::create_sticky_object(@blaze_token_launchpad);
        let fa_obj_signer = &object::generate_signer(fa_obj_constructor_ref);
        
        // Create fungible asset
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            fa_obj_constructor_ref,
            max_supply,
            name,
            ticker,
            decimals,
            token_image_uri,
            std::string::utf8(b"https://blaze-launchpad.xyz")  // project URI
        );
        
        let fa_obj = object::object_from_constructor_ref(fa_obj_constructor_ref);
        
        // Generate and store capabilities
        let mint_ref = fungible_asset::generate_mint_ref(fa_obj_constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(fa_obj_constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(fa_obj_constructor_ref);
        
        move_to(
            fa_obj_signer,
            FAController { mint_ref, burn_ref, transfer_ref }
        );
        
        // Store metadata
        let social_links = SocialLinks {
            website,
            twitter,
            telegram,
            discord
        };
        
        let metadata = TokenMetadata {
            name,
            ticker,
            token_image_uri,
            description,
            social_links,
            created_at: now(),
            creator: sender_addr
        };
        
        // Store Bancor curve
        let curve = BancorCurve {
            reserve_ratio,
            reserve_balance: initial_apt_reserve,
            is_active: true
        };
        
        // Store pool settings
        let threshold = if (market_cap_threshold_usd.is_some()) {
            *market_cap_threshold_usd.borrow()
        } else {
            DEFAULT_MARKET_CAP_THRESHOLD_USD
        };
        
        let settings = PoolSettings {
            market_cap_threshold_usd: threshold,
            hyperion_pool_address: option::none(),
            migration_completed: false,
            migration_timestamp: option::none(),
            trading_enabled: true
        };
        
        move_to(
            fa_obj_signer,
            Pool {
                metadata,
                curve,
                settings
            }
        );
        
        // Transfer initial APT reserve to pool (resource account)
        if (initial_apt_reserve > 0) {
            let resource_addr = get_resource_account_addr();
            aptos_account::transfer(sender, resource_addr, initial_apt_reserve);
        };
        
        // Add to registry
        let registry = borrow_global_mut<Registry>(@blaze_token_launchpad);
        vector::push_back(&mut registry.pools, fa_obj);
        
        // Emit event
        event::emit(
            CreatePoolEvent {
                pool_id: fa_obj,
                creator: sender_addr,
                name: metadata.name,
                ticker: metadata.ticker,
                reserve_ratio,
                initial_reserve: initial_apt_reserve,
                market_cap_threshold_usd: threshold,
                timestamp: now()
            }
        );
    }

    /// Buy tokens using APT via Bancor bonding curve
    public entry fun buy(
        sender: &signer,
        pool_id: Object<Metadata>,
        apt_amount: u64,
        min_tokens_out: u64,
        deadline: u64
    ) acquires Pool, FAController, FeeConfig, LiquidityPool, ResourceAccountCapability {
        let sender_addr = signer::address_of(sender);
        
        // Validate inputs
        assert!(apt_amount > 0, EINVALID_AMOUNT);
        assert!(now() <= deadline, EDEADLINE_PASSED);
        
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global_mut<Pool>(pool_addr);
        assert!(pool.curve.is_active, ETRADING_DISABLED);
        assert!(pool.settings.trading_enabled, ETRADING_DISABLED);
        
        // Get current supply
        let supply = fungible_asset::supply(pool_id);
        let current_supply = if (supply.is_some()) { *supply.borrow() } else { 0 };
        
        // Calculate and deduct fee
        let fee_config = borrow_global<FeeConfig>(@blaze_token_launchpad);
        let fee_amount = calculate_fee(apt_amount, fee_config.buy_fee_bps);
        let apt_for_reserve = apt_amount - fee_amount;
        
        // Recalculate with net amount
        let tokens_to_mint = calculate_bancor_purchase_return(
            current_supply,
            pool.curve.reserve_balance,
            pool.curve.reserve_ratio,
            apt_for_reserve
        );
        
        // Check slippage
        assert!(tokens_to_mint >= min_tokens_out, ESLIPPAGE_EXCEEDED);
        
        // Transfer APT from user
        let resource_addr = get_resource_account_addr();
        aptos_account::transfer(sender, resource_addr, apt_for_reserve);
        
        // Transfer fee to treasury
        if (fee_amount > 0) {
            aptos_account::transfer(sender, fee_config.treasury_addr, fee_amount);
        };
        
        // Update reserve balance
        pool.curve.reserve_balance = pool.curve.reserve_balance + apt_for_reserve;
        
        // Update liquidity tracking
        let liquidity = borrow_global_mut<LiquidityPool>(@blaze_token_launchpad);
        liquidity.total_apt_collected = liquidity.total_apt_collected + apt_for_reserve;
        
        // Mint tokens to user
        let fa_controller = borrow_global<FAController>(pool_addr);
        primary_fungible_store::mint(&fa_controller.mint_ref, sender_addr, tokens_to_mint);
        
        // Calculate new price and supply
        let new_supply = current_supply + (tokens_to_mint as u128);
        let new_price = calculate_current_price(
            new_supply,
            pool.curve.reserve_balance,
            pool.curve.reserve_ratio
        );
        
        // Emit event
        event::emit(
            BuyEvent {
                pool_id,
                buyer: sender_addr,
                apt_spent: apt_amount,
                tokens_received: tokens_to_mint,
                fee_collected: fee_amount,
                new_price,
                new_supply,
                timestamp: now()
            }
        );
        
        // TODO: Check market cap and trigger migration if threshold reached
    }

    /// Sell tokens for APT via Bancor bonding curve
    public entry fun sell(
        sender: &signer,
        pool_id: Object<Metadata>,
        token_amount: u64,
        min_apt_out: u64,
        deadline: u64
    ) acquires Pool, FAController, FeeConfig, LiquidityPool, ResourceAccountCapability {
        let sender_addr = signer::address_of(sender);
        
        // Validate inputs
        assert!(token_amount > 0, EINVALID_AMOUNT);
        assert!(now() <= deadline, EDEADLINE_PASSED);
        
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global_mut<Pool>(pool_addr);
        assert!(pool.curve.is_active, ETRADING_DISABLED);
        assert!(pool.settings.trading_enabled, ETRADING_DISABLED);
        
        // Check user balance
        let user_balance = primary_fungible_store::balance(sender_addr, pool_id);
        assert!(user_balance >= token_amount, EINSUFFICIENT_BALANCE);
        
        // Get current supply
        let supply = fungible_asset::supply(pool_id);
        let current_supply = if (supply.is_some()) { *supply.borrow() } else { 0 };
        
        // Calculate APT to receive (before fee)
        let apt_before_fee = calculate_bancor_sale_return(
            current_supply,
            pool.curve.reserve_balance,
            pool.curve.reserve_ratio,
            token_amount
        );
        
        // Calculate and deduct fee
        let fee_config = borrow_global<FeeConfig>(@blaze_token_launchpad);
        let fee_amount = calculate_fee(apt_before_fee, fee_config.sell_fee_bps);
        let apt_to_return = apt_before_fee - fee_amount;
        
        // Check slippage
        assert!(apt_to_return >= min_apt_out, ESLIPPAGE_EXCEEDED);
        
        // Check reserve has enough APT
        assert!(pool.curve.reserve_balance >= apt_before_fee, EINSUFFICIENT_LIQUIDITY);
        
        // Burn tokens from user
        let fa_controller = borrow_global<FAController>(pool_addr);
        primary_fungible_store::burn(&fa_controller.burn_ref, sender_addr, token_amount);
        
        // Update reserve balance
        pool.curve.reserve_balance = pool.curve.reserve_balance - apt_before_fee;
        
        // Update liquidity tracking
        let liquidity = borrow_global_mut<LiquidityPool>(@blaze_token_launchpad);
        liquidity.total_apt_paid_out = liquidity.total_apt_paid_out + apt_to_return;
        
        // Transfer APT to user
        let resource_signer = get_resource_account_signer();
        aptos_account::transfer(&resource_signer, sender_addr, apt_to_return);
        
        // Transfer fee to treasury
        if (fee_amount > 0) {
            aptos_account::transfer(&resource_signer, fee_config.treasury_addr, fee_amount);
        };
        
        // Calculate new price and supply
        let new_supply = current_supply - (token_amount as u128);
        let new_price = calculate_current_price(
            new_supply,
            pool.curve.reserve_balance,
            pool.curve.reserve_ratio
        );
        
        // Emit event
        event::emit(
            SellEvent {
                pool_id,
                seller: sender_addr,
                tokens_sold: token_amount,
                apt_received: apt_to_return,
                fee_collected: fee_amount,
                new_price,
                new_supply,
                timestamp: now()
            }
        );
    }

    // ================================= Admin Functions ================================= //

    /// Set new admin address
    public entry fun set_admin(
        sender: &signer,
        new_admin: address
    ) acquires Config {
        let sender_addr = signer::address_of(sender);
        assert_admin(sender_addr);
        
        let config = borrow_global_mut<Config>(@blaze_token_launchpad);
        let old_admin = config.admin_addr;
        config.admin_addr = new_admin;
        
        event::emit(
            AdminChangedEvent {
                old_admin,
                new_admin,
                timestamp: now()
            }
        );
    }

    /// Set new treasury address
    public entry fun set_treasury(
        sender: &signer,
        new_treasury: address
    ) acquires Config, FeeConfig {
        let sender_addr = signer::address_of(sender);
        assert_admin(sender_addr);
        
        let config = borrow_global_mut<Config>(@blaze_token_launchpad);
        let old_treasury = config.treasury_addr;
        config.treasury_addr = new_treasury;
        
        let fee_config = borrow_global_mut<FeeConfig>(@blaze_token_launchpad);
        fee_config.treasury_addr = new_treasury;
        
        event::emit(
            TreasuryChangedEvent {
                old_treasury,
                new_treasury,
                timestamp: now()
            }
        );
    }

    /// Update trading fees
    public entry fun update_fee(
        sender: &signer,
        buy_fee_bps: u64,
        sell_fee_bps: u64
    ) acquires Config, FeeConfig {
        let sender_addr = signer::address_of(sender);
        assert_admin(sender_addr);
        
        assert!(buy_fee_bps <= MAX_FEE_BPS, EFEE_TOO_HIGH);
        assert!(sell_fee_bps <= MAX_FEE_BPS, EFEE_TOO_HIGH);
        
        let fee_config = borrow_global_mut<FeeConfig>(@blaze_token_launchpad);
        let old_buy = fee_config.buy_fee_bps;
        let old_sell = fee_config.sell_fee_bps;
        
        fee_config.buy_fee_bps = buy_fee_bps;
        fee_config.sell_fee_bps = sell_fee_bps;
        
        event::emit(
            FeeUpdatedEvent {
                old_buy_fee_bps: old_buy,
                new_buy_fee_bps: buy_fee_bps,
                old_sell_fee_bps: old_sell,
                new_sell_fee_bps: sell_fee_bps,
                timestamp: now()
            }
        );
    }

    /// Update pool settings
    public entry fun update_pool_settings(
        sender: &signer,
        pool_id: Object<Metadata>,
        market_cap_threshold_usd: Option<u64>,
        trading_enabled: Option<bool>
    ) acquires Config, Pool {
        let sender_addr = signer::address_of(sender);
        assert_admin(sender_addr);
        
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global_mut<Pool>(pool_addr);
        
        if (market_cap_threshold_usd.is_some()) {
            pool.settings.market_cap_threshold_usd = *market_cap_threshold_usd.borrow();
        };
        
        if (trading_enabled.is_some()) {
            pool.settings.trading_enabled = *trading_enabled.borrow();
        };
        
        event::emit(
            PoolSettingsUpdatedEvent {
                pool_id,
                market_cap_threshold_usd: pool.settings.market_cap_threshold_usd,
                trading_enabled: pool.settings.trading_enabled,
                timestamp: now()
            }
        );
    }

    /// Admin withdrawal from pool (emergency function)
    public entry fun transfer_to_admin(
        sender: &signer,
        pool_id: Object<Metadata>,
        amount: u64
    ) acquires Config, Pool, ResourceAccountCapability {
        let sender_addr = signer::address_of(sender);
        assert_admin(sender_addr);
        
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global_mut<Pool>(pool_addr);
        assert!(pool.curve.reserve_balance >= amount, EINSUFFICIENT_RESERVE);
        
        // Update reserve
        pool.curve.reserve_balance = pool.curve.reserve_balance - amount;
        
        // Transfer from resource account to admin
        let resource_signer = get_resource_account_signer();
        aptos_account::transfer(&resource_signer, sender_addr, amount);
        
        event::emit(
            AdminWithdrawalEvent {
                pool_id,
                admin: sender_addr,
                amount,
                timestamp: now()
            }
        );
    }

    // ================================= View Functions ================================= //

    #[view]
    /// Get admin address
    public fun get_admin(): address acquires Config {
        let config = borrow_global<Config>(@blaze_token_launchpad);
        config.admin_addr
    }

    #[view]
    /// Get treasury address
    public fun get_treasury(): address acquires Config {
        let config = borrow_global<Config>(@blaze_token_launchpad);
        config.treasury_addr
    }

    #[view]
    /// Get all pool IDs
    public fun get_pools(): vector<Object<Metadata>> acquires Registry {
        let registry = borrow_global<Registry>(@blaze_token_launchpad);
        registry.pools
    }

    #[view]
    /// Get fees (buy_fee_bps, sell_fee_bps)
    public fun get_fees(): (u64, u64) acquires FeeConfig {
        let fee_config = borrow_global<FeeConfig>(@blaze_token_launchpad);
        (fee_config.buy_fee_bps, fee_config.sell_fee_bps)
    }

    #[view]
    /// Get pool data
    public fun get_pool(pool_id: Object<Metadata>): (TokenMetadata, BancorCurve, PoolSettings) acquires Pool {
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global<Pool>(pool_addr);
        (pool.metadata, pool.curve, pool.settings)
    }

    #[view]
    /// Get pool balance (APT reserve)
    public fun get_pool_balance(pool_id: Object<Metadata>): u64 acquires Pool {
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global<Pool>(pool_addr);
        pool.curve.reserve_balance
    }

    #[view]
    /// Get curve data
    public fun get_curve_data(pool_id: Object<Metadata>): BancorCurve acquires Pool {
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global<Pool>(pool_addr);
        pool.curve
    }

    #[view]
    /// Get pool settings
    public fun calculate_pool_settings(pool_id: Object<Metadata>): PoolSettings acquires Pool {
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global<Pool>(pool_addr);
        pool.settings
    }

    #[view]
    /// Get current token supply
    public fun get_current_supply(pool_id: Object<Metadata>): u128 {
        let supply = fungible_asset::supply(pool_id);
        if (supply.is_some()) { *supply.borrow() } else { 0 }
    }

    #[view]
    /// Get current price per token (u64)
    public fun get_current_price(pool_id: Object<Metadata>): u64 acquires Pool {
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global<Pool>(pool_addr);
        let supply = get_current_supply(pool_id);
        
        calculate_current_price(supply, pool.curve.reserve_balance, pool.curve.reserve_ratio)
    }

    #[view]
    /// Get current price per token (u256 for higher precision)
    public fun get_current_price_u256(pool_id: Object<Metadata>): u256 acquires Pool {
        (get_current_price(pool_id) as u256)
    }

    #[view]
    /// Calculate tokens received for APT amount (before fees)
    public fun calculate_curved_mint_return(
        pool_id: Object<Metadata>,
        apt_amount: u64
    ): u64 acquires Pool {
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global<Pool>(pool_addr);
        let supply = get_current_supply(pool_id);
        
        calculate_bancor_purchase_return(
            supply,
            pool.curve.reserve_balance,
            pool.curve.reserve_ratio,
            apt_amount
        )
    }

    #[view]
    /// Calculate APT received for token amount (before fees)
    public fun calculate_curved_burn_return(
        pool_id: Object<Metadata>,
        token_amount: u64
    ): u64 acquires Pool {
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global<Pool>(pool_addr);
        let supply = get_current_supply(pool_id);
        
        calculate_bancor_sale_return(
            supply,
            pool.curve.reserve_balance,
            pool.curve.reserve_ratio,
            token_amount
        )
    }

    #[view]
    /// Calculate purchase return using Bancor formula (pure calculation)
    public fun calculate_purchance_return_bancor(
        supply: u128,
        reserve_balance: u64,
        reserve_ratio: u64,
        deposit_amount: u64
    ): u64 {
        calculate_bancor_purchase_return(supply, reserve_balance, reserve_ratio, deposit_amount)
    }

    #[view]
    /// Calculate sale return using Bancor formula (pure calculation)
    public fun calculate_sale_return_bancor(
        supply: u128,
        reserve_balance: u64,
        reserve_ratio: u64,
        sell_amount: u64
    ): u64 {
        calculate_bancor_sale_return(supply, reserve_balance, reserve_ratio, sell_amount)
    }

    #[view]
    /// Get all token metadata
    public fun get_tokens(): vector<TokenMetadata> acquires Registry, Pool {
        let registry = borrow_global<Registry>(@blaze_token_launchpad);
        let pools = registry.pools;
        let result = vector::empty<TokenMetadata>();
        
        let i = 0;
        let len = vector::length(&pools);
        while (i < len) {
            let pool_id = *vector::borrow(&pools, i);
            let pool_addr = object::object_address(&pool_id);
            if (exists<Pool>(pool_addr)) {
                let pool = borrow_global<Pool>(pool_addr);
                vector::push_back(&mut result, pool.metadata);
            };
            i = i + 1;
        };
        
        result
    }

    #[view]
    /// Get maximum APT that can be withdrawn if all tokens are sold (before fees)
    public fun get_max_left_apt_in_pool(pool_id: Object<Metadata>): u64 acquires Pool {
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), EPOOL_NOT_FOUND);
        
        let pool = borrow_global<Pool>(pool_addr);
        let supply = get_current_supply(pool_id);
        
        if (supply == 0) {
            return pool.curve.reserve_balance
        };
        
        // Calculate how much APT would be returned if all tokens are sold
        calculate_bancor_sale_return(
            supply,
            pool.curve.reserve_balance,
            pool.curve.reserve_ratio,
            (supply as u64)
        )
    }

    #[view]
    /// Get maximum APT that can be withdrawn if all tokens are sold (after fees)
    public fun get_max_left_apt_in_pool_including_fee(pool_id: Object<Metadata>): u64 acquires Pool, FeeConfig {
        let apt_before_fee = get_max_left_apt_in_pool(pool_id);
        let fee_config = borrow_global<FeeConfig>(@blaze_token_launchpad);
        let fee = calculate_fee(apt_before_fee, fee_config.sell_fee_bps);
        apt_before_fee - fee
    }

    #[view]
    /// Get resource account address
    public fun get_resource_account_address(): address acquires ResourceAccountCapability {
        get_resource_account_addr()
    }

    // ================================= Tests ================================= //

    #[test_only]
    use aptos_framework::account as test_account;

    #[test_only]
    struct AptosCoinCap has key {
        burn_cap: coin::BurnCapability<aptos_coin::AptosCoin>,
        mint_cap: coin::MintCapability<aptos_coin::AptosCoin>
    }

    #[test_only]
    fun setup_test(aptos_framework: &signer, sender: &signer): address {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        move_to(aptos_framework, AptosCoinCap { burn_cap, mint_cap });
        let sender_addr = signer::address_of(sender);
        test_account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);
        init_module(sender);
        sender_addr
    }

    #[test_only]
    /// Helper function to create a test pool
    fun create_test_pool(
        sender: &signer,
        name: String,
        ticker: String,
        reserve_ratio: u64,
        initial_reserve: u64
    ): Object<Metadata> acquires Registry, ResourceAccountCapability {
        create_pool(
            sender,
            name,
            ticker,
            string::utf8(b"https://example.com/image.png"),
            option::some(string::utf8(b"Test token description")),
            option::some(string::utf8(b"https://example.com")),
            option::some(string::utf8(b"@testtoken")),
            option::some(string::utf8(b"t.me/testtoken")),
            option::some(string::utf8(b"discord.gg/testtoken")),
            option::some(1000000000),
            8,
            reserve_ratio,
            initial_reserve,
            option::some(7500000)
        );
        
        let registry = borrow_global<Registry>(@blaze_token_launchpad);
        *vector::borrow(&registry.pools, vector::length(&registry.pools) - 1)
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_init_module(aptos_framework: &signer, sender: &signer) {
        setup_test(aptos_framework, sender);
        
        // Verify all global resources are initialized
        assert!(exists<Registry>(@blaze_token_launchpad), 1);
        assert!(exists<Config>(@blaze_token_launchpad), 2);
        assert!(exists<FeeConfig>(@blaze_token_launchpad), 3);
        assert!(exists<LiquidityPool>(@blaze_token_launchpad), 4);
        assert!(exists<ResourceAccountCapability>(@blaze_token_launchpad), 5);
        assert!(exists<PriceOracle>(@blaze_token_launchpad), 6);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_create_pool_basic(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        // Mint APT for initial reserve
        aptos_coin::mint(aptos_framework, sender_addr, 1000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000
        );
        
        // Verify pool exists
        let pool_addr = object::object_address(&pool_id);
        assert!(exists<Pool>(pool_addr), 10);
        assert!(exists<FAController>(pool_addr), 11);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_buy_tokens(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, FAController, FeeConfig, LiquidityPool, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        // Mint APT for initial reserve and buy
        aptos_coin::mint(aptos_framework, sender_addr, 2000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000  // 1 APT initial reserve
        );
        
        // Buy tokens
        let buy_amount = 10000000; // 0.1 APT
        let initial_balance = primary_fungible_store::balance(sender_addr, pool_id);
        
        buy(sender, pool_id, buy_amount, 0, timestamp::now_seconds() + 300);
        
        let final_balance = primary_fungible_store::balance(sender_addr, pool_id);
        assert!(final_balance > initial_balance, 20);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_buy_and_sell_tokens(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, FAController, FeeConfig, LiquidityPool, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        // Mint APT
        aptos_coin::mint(aptos_framework, sender_addr, 2000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000
        );
        
        // Buy tokens
        buy(sender, pool_id, 50000000, 0, timestamp::now_seconds() + 300);
        
        let token_balance = primary_fungible_store::balance(sender_addr, pool_id);
        assert!(token_balance > 0, 30);
        
        // Sell half the tokens
        let sell_amount = token_balance / 2;
        sell(sender, pool_id, sell_amount, 0, timestamp::now_seconds() + 300);
        
        let final_balance = primary_fungible_store::balance(sender_addr, pool_id);
        assert!(final_balance < token_balance, 31);
        assert!(final_balance > 0, 32);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_bancor_calculations(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        aptos_coin::mint(aptos_framework, sender_addr, 2000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000
        );
        
        // Test purchase calculation
        let tokens = calculate_curved_mint_return(pool_id, 10000000);
        assert!(tokens > 0, 40);
        
        // Test sale calculation (should be 0 when supply is 0)
        let apt = calculate_curved_burn_return(pool_id, 1000);
        assert!(apt == 0, 41);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_price_increases_with_supply(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, FAController, FeeConfig, LiquidityPool, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        aptos_coin::mint(aptos_framework, sender_addr, 5000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000
        );
        
        // Get initial price (should be 0 with 0 supply)
        let initial_price = get_current_price(pool_id);
        
        // Buy tokens to increase supply
        buy(sender, pool_id, 100000000, 0, timestamp::now_seconds() + 300);
        
        // Price should increase
        let new_price = get_current_price(pool_id);
        assert!(new_price > initial_price, 50);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_fees_collected(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, FAController, FeeConfig, LiquidityPool, ResourceAccountCapability, Config {
        let sender_addr = setup_test(aptos_framework, sender);
        
        // Get treasury address
        let treasury = get_treasury();
        if (!test_account::exists_at(treasury)) {
            test_account::create_account_for_test(treasury);
        };
        if (!coin::is_account_registered<aptos_coin::AptosCoin>(treasury)) {
            coin::register<aptos_coin::AptosCoin>(sender); // Register sender as treasury for test
        };
        
        aptos_coin::mint(aptos_framework, sender_addr, 2000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000
        );
        
        // Buy tokens (1% fee should be collected)
        let buy_amount = 100000000;
        buy(sender, pool_id, buy_amount, 0, timestamp::now_seconds() + 300);
        
        // Verify fees were deducted
        let (buy_fee_bps, _sell_fee_bps) = get_fees();
        let expected_fee = (buy_amount * buy_fee_bps) / 10000;
        assert!(expected_fee > 0, 60);
    }

    #[test(aptos_framework = @0x1, admin = @blaze_token_launchpad, new_admin = @0x123)]
    fun test_set_admin(
        aptos_framework: &signer,
        admin: &signer,
        new_admin: address
    ) acquires Config {
        setup_test(aptos_framework, admin);
        
        let initial_admin = get_admin();
        assert!(initial_admin == signer::address_of(admin), 70);
        
        set_admin(admin, new_admin);
        
        let current_admin = get_admin();
        assert!(current_admin == new_admin, 71);
    }

    #[test(aptos_framework = @0x1, admin = @blaze_token_launchpad, new_treasury = @0x456)]
    fun test_set_treasury(
        aptos_framework: &signer,
        admin: &signer,
        new_treasury: address
    ) acquires Config, FeeConfig {
        setup_test(aptos_framework, admin);
        
        let initial_treasury = get_treasury();
        
        set_treasury(admin, new_treasury);
        
        let current_treasury = get_treasury();
        assert!(current_treasury == new_treasury, 80);
        assert!(current_treasury != initial_treasury, 81);
    }

    #[test(aptos_framework = @0x1, admin = @blaze_token_launchpad)]
    fun test_update_fee(
        aptos_framework: &signer,
        admin: &signer
    ) acquires Config, FeeConfig {
        setup_test(aptos_framework, admin);
        
        let (initial_buy, initial_sell) = get_fees();
        
        update_fee(admin, 200, 300);
        
        let (new_buy, new_sell) = get_fees();
        assert!(new_buy == 200, 90);
        assert!(new_sell == 300, 91);
        assert!(new_buy != initial_buy || new_sell != initial_sell, 92);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_pool_settings(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, Config, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        aptos_coin::mint(aptos_framework, sender_addr, 2000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000
        );
        
        // Get initial settings
        let settings = calculate_pool_settings(pool_id);
        assert!(settings.trading_enabled == true, 100);
        
        // Update settings
        update_pool_settings(sender, pool_id, option::some(10000000), option::some(false));
        
        let new_settings = calculate_pool_settings(pool_id);
        assert!(new_settings.trading_enabled == false, 101);
        assert!(new_settings.market_cap_threshold_usd == 10000000, 102);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    #[expected_failure(abort_code = ETRADING_DISABLED)]
    fun test_buy_when_trading_disabled(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, FAController, FeeConfig, LiquidityPool, ResourceAccountCapability, Config {
        let sender_addr = setup_test(aptos_framework, sender);
        
        aptos_coin::mint(aptos_framework, sender_addr, 2000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000
        );
        
        // Disable trading
        update_pool_settings(sender, pool_id, option::none(), option::some(false));
        
        // This should fail
        buy(sender, pool_id, 10000000, 0, timestamp::now_seconds() + 300);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    #[expected_failure(abort_code = ESLIPPAGE_EXCEEDED)]
    fun test_slippage_protection(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, FAController, FeeConfig, LiquidityPool, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        aptos_coin::mint(aptos_framework, sender_addr, 2000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000
        );
        
        // Set unrealistic min_tokens_out - should fail
        buy(sender, pool_id, 10000000, 999999999, timestamp::now_seconds() + 300);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    #[expected_failure(abort_code = EDEADLINE_PASSED)]
    fun test_deadline_enforcement(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, FAController, FeeConfig, LiquidityPool, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        aptos_coin::mint(aptos_framework, sender_addr, 2000000000);
        
        let pool_id = create_test_pool(
            sender,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST"),
            50,
            100000000
        );
        
        // Fast forward time to make deadline in the past
        timestamp::fast_forward_seconds(100);
        
        // Set deadline in the past - should fail
        buy(sender, pool_id, 10000000, 0, 50);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_multiple_pools(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        aptos_coin::mint(aptos_framework, sender_addr, 5000000000);
        
        // Create multiple pools
        create_test_pool(sender, string::utf8(b"Token 1"), string::utf8(b"TK1"), 50, 100000000);
        create_test_pool(sender, string::utf8(b"Token 2"), string::utf8(b"TK2"), 75, 200000000);
        create_test_pool(sender, string::utf8(b"Token 3"), string::utf8(b"TK3"), 25, 150000000);
        
        let pools = get_pools();
        assert!(vector::length(&pools) == 3, 110);
        
        let tokens = get_tokens();
        assert!(vector::length(&tokens) == 3, 111);
    }

    #[test(aptos_framework = @0x1, sender = @blaze_token_launchpad)]
    fun test_reserve_ratios(
        aptos_framework: &signer,
        sender: &signer
    ) acquires Registry, Pool, ResourceAccountCapability {
        let sender_addr = setup_test(aptos_framework, sender);
        
        aptos_coin::mint(aptos_framework, sender_addr, 5000000000);
        
        // Test different reserve ratios
        let pool_25 = create_test_pool(sender, string::utf8(b"Token 25"), string::utf8(b"T25"), 25, 100000000);
        let pool_50 = create_test_pool(sender, string::utf8(b"Token 50"), string::utf8(b"T50"), 50, 100000000);
        let pool_100 = create_test_pool(sender, string::utf8(b"Token 100"), string::utf8(b"T100"), 100, 100000000);
        
        let curve_25 = get_curve_data(pool_25);
        let curve_50 = get_curve_data(pool_50);
        let curve_100 = get_curve_data(pool_100);
        
        assert!(curve_25.reserve_ratio == 25, 120);
        assert!(curve_50.reserve_ratio == 50, 121);
        assert!(curve_100.reserve_ratio == 100, 122);
    }
}
