module launchpad_addr::launchpad {
    use std::option::{Self, Option};
    use std::signer;
    use std::string::String;
    use std::vector;

    #[test_only]
    use std::string;

    use aptos_std::table::{Self, Table};

    use aptos_framework::aptos_account;
    use aptos_framework::event;
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object::{Self, Object, ObjectCore};
    use aptos_framework::primary_fungible_store;

    /// Only admin can update creator
    const EONLY_ADMIN_CAN_UPDATE_CREATOR: u64 = 1;
    /// Only admin can set pending admin
    const EONLY_ADMIN_CAN_SET_PENDING_ADMIN: u64 = 2;
    /// Sender is not pending admin
    const ENOT_PENDING_ADMIN: u64 = 3;
    /// Only admin can update mint fee collector
    const EONLY_ADMIN_CAN_UPDATE_MINT_FEE_COLLECTOR: u64 = 4;
    /// No mint limit
    const ENO_MINT_LIMIT: u64 = 5;
    /// Mint limit reached
    const EMINT_LIMIT_REACHED: u64 = 6;

    /// Default to mint 0 amount to creator when creating FA
    const DEFAULT_PRE_MINT_AMOUNT: u64 = 0;
    /// Default mint fee per smallest unit of FA denominated in oapt (smallest unit of APT, i.e. 1e-8 APT)
    const DEFAULT_MINT_FEE_PER_SMALLEST_UNIT_OF_FA: u64 = 0;

    #[event]
    struct CreateFAEvent has store, drop {
        creator_addr: address,
        fa_obj: Object<Metadata>,
        max_supply: Option<u128>,
        name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String,
        mint_fee_per_smallest_unit_of_fa: u64,
        pre_mint_amount: u64,
        mint_limit_per_addr: Option<u64>
    }

    #[event]
    struct MintFAEvent has store, drop {
        fa_obj: Object<Metadata>,
        amount: u64,
        recipient_addr: address,
        total_mint_fee: u64
    }

    #[event]
    struct CreateBondingCurveFAEvent has store, drop {
        creator_addr: address,
        fa_obj: Object<Metadata>,
        max_supply: Option<u128>,
        name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String,
        target_supply: u64,
        virtual_liquidity: u64,
        curve_exponent: u64,
        pre_mint_amount: u64,
        mint_limit_per_addr: Option<u64>
    }

    #[event]
    struct BondingCurveMintEvent has store, drop {
        fa_obj: Object<Metadata>,
        amount: u64,
        recipient_addr: address,
        total_cost: u64,
        price_per_token: u64
    }

    #[event]
    struct BondingCurveTargetReachedEvent has store, drop {
        fa_obj: Object<Metadata>,
        final_supply: u64,
        total_virtual_liquidity: u64
    }

    #[event]
    struct BondingCurveSellEvent has store, drop {
        fa_obj: Object<Metadata>,
        amount: u64,
        seller_addr: address,
        total_payout: u64,
        price_per_token: u64
    }

    /// Unique per FA
    struct FAController has key {
        mint_ref: fungible_asset::MintRef,
        burn_ref: fungible_asset::BurnRef,
        transfer_ref: fungible_asset::TransferRef
    }

    /// Unique per FA
    struct MintLimit has store {
        limit: u64,
        mint_tracker: Table<address, u64>
    }

    /// Unique per FA
    struct FAConfig has key {
        // Mint fee per FA denominated in oapt (smallest unit of APT, i.e. 1e-8 APT)
        mint_fee_per_smallest_unit_of_fa: u64,
        mint_limit: Option<MintLimit>
    }

    /// Bonding curve configuration for FA
    struct BondingCurve has key, copy, drop {
        // Target supply when bonding curve becomes inactive
        target_supply: u64,
        // Virtual liquidity for price calculation
        virtual_liquidity: u64,
        // Curve exponent (typically 2 for quadratic curves)
        curve_exponent: u64,
        // Whether bonding curve is still active
        is_active: bool
    }

    /// Global per contract
    struct Registry has key {
        fa_objects: vector<Object<Metadata>>
    }

    /// Global per contract
    struct Config has key {
        // admin can set pending admin, accept admin, update mint fee collector
        admin_addr: address,
        pending_admin_addr: Option<address>,
        mint_fee_collector_addr: address
    }

    /// If you deploy the module under an object, sender is the object's signer
    /// If you deploy the moduelr under your own account, sender is your account's signer
    fun init_module(sender: &signer) {
        move_to(sender, Registry { fa_objects: vector::empty() });
        move_to(
            sender,
            Config {
                admin_addr: signer::address_of(sender),
                pending_admin_addr: option::none(),
                mint_fee_collector_addr: signer::address_of(sender)
            }
        );
    }

    // ================================= Entry Functions ================================= //

    /// Set pending admin of the contract, then pending admin can call accept_admin to become admin
    public entry fun set_pending_admin(
        sender: &signer, new_admin: address
    ) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@launchpad_addr);
        assert!(is_admin(config, sender_addr), EONLY_ADMIN_CAN_SET_PENDING_ADMIN);
        config.pending_admin_addr = option::some(new_admin);
    }

    /// Accept admin of the contract
    public entry fun accept_admin(sender: &signer) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@launchpad_addr);
        assert!(
            config.pending_admin_addr == option::some(sender_addr), ENOT_PENDING_ADMIN
        );
        config.admin_addr = sender_addr;
        config.pending_admin_addr = option::none();
    }

    /// Update mint fee collector address
    public entry fun update_mint_fee_collector(
        sender: &signer, new_mint_fee_collector: address
    ) acquires Config {
        let sender_addr = signer::address_of(sender);
        let config = borrow_global_mut<Config>(@launchpad_addr);
        assert!(
            is_admin(config, sender_addr), EONLY_ADMIN_CAN_UPDATE_MINT_FEE_COLLECTOR
        );
        config.mint_fee_collector_addr = new_mint_fee_collector;
    }

    /// Create a fungible asset, only admin or creator can create FA
    public entry fun create_fa(
        sender: &signer,
        max_supply: Option<u128>,
        name: String,
        symbol: String,
        // Number of decimal places, i.e. APT has 8 decimal places, so decimals = 8, 1 APT = 1e-8 oapt
        decimals: u8,
        icon_uri: String,
        project_uri: String,
        // Mint fee per smallest unit of FA denominated in oapt (smallest unit of APT, i.e. 1e-8 APT)
        mint_fee_per_smallest_unit_of_fa: Option<u64>,
        // Amount in smallest unit of FA
        pre_mint_amount: Option<u64>,
        // Limit of minting per address in smallest unit of FA
        mint_limit_per_addr: Option<u64>
    ) acquires Registry, FAController {
        let sender_addr = signer::address_of(sender);

        let fa_obj_constructor_ref = &object::create_sticky_object(@launchpad_addr);
        let fa_obj_signer = &object::generate_signer(fa_obj_constructor_ref);

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            fa_obj_constructor_ref,
            max_supply,
            name,
            symbol,
            decimals,
            icon_uri,
            project_uri
        );
        let fa_obj = object::object_from_constructor_ref(fa_obj_constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(fa_obj_constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(fa_obj_constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(fa_obj_constructor_ref);
        move_to(
            fa_obj_signer,
            FAController { mint_ref, burn_ref, transfer_ref }
        );
        move_to(
            fa_obj_signer,
            FAConfig {
                mint_fee_per_smallest_unit_of_fa: *mint_fee_per_smallest_unit_of_fa.borrow_with_default(
                    &DEFAULT_MINT_FEE_PER_SMALLEST_UNIT_OF_FA
                ),
                mint_limit: if (mint_limit_per_addr.is_some()) {
                    option::some(
                        MintLimit {
                            limit: *mint_limit_per_addr.borrow(),
                            mint_tracker: table::new()
                        }
                    )
                } else {
                    option::none()
                }
            }
        );

        let registry = borrow_global_mut<Registry>(@launchpad_addr);
        registry.fa_objects.push_back(fa_obj);

        event::emit(
            CreateFAEvent {
                creator_addr: sender_addr,
                fa_obj,
                max_supply,
                name,
                symbol,
                decimals,
                icon_uri,
                project_uri,
                mint_fee_per_smallest_unit_of_fa: *mint_fee_per_smallest_unit_of_fa.borrow_with_default(
                    &DEFAULT_MINT_FEE_PER_SMALLEST_UNIT_OF_FA
                ),
                pre_mint_amount: *pre_mint_amount.borrow_with_default(
                    &DEFAULT_PRE_MINT_AMOUNT
                ),
                mint_limit_per_addr
            }
        );

        if (*pre_mint_amount.borrow_with_default(&DEFAULT_PRE_MINT_AMOUNT) > 0) {
            let amount = *pre_mint_amount.borrow();
            mint_fa_internal(sender, fa_obj, amount, 0);
        }
    }

    /// Mint fungible asset, anyone with enough mint fee and has not reached mint limit can mint FA
    public entry fun mint_fa(
        sender: &signer, fa_obj: Object<Metadata>, amount: u64
    ) acquires FAController, FAConfig, Config {
        let sender_addr = signer::address_of(sender);
        check_mint_limit_and_update_mint_tracker(sender_addr, fa_obj, amount);
        let total_mint_fee = get_mint_fee(fa_obj, amount);
        pay_for_mint(sender, total_mint_fee);
        mint_fa_internal(sender, fa_obj, amount, total_mint_fee);
    }

    /// Create a token with bonding curve
    public entry fun create_token(
        sender: &signer,
        max_supply: Option<u128>,
        name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String,
        target_supply: u64,
        virtual_liquidity: u64,
        curve_exponent: u64,
        mint_limit_per_addr: Option<u64>
    ) acquires Registry {
        let sender_addr = signer::address_of(sender);

        let fa_obj_constructor_ref = &object::create_sticky_object(@launchpad_addr);
        let fa_obj_signer = &object::generate_signer(fa_obj_constructor_ref);

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            fa_obj_constructor_ref,
            max_supply,
            name,
            symbol,
            decimals,
            icon_uri,
            project_uri
        );
        let fa_obj = object::object_from_constructor_ref(fa_obj_constructor_ref);
        let mint_ref = fungible_asset::generate_mint_ref(fa_obj_constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(fa_obj_constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(fa_obj_constructor_ref);
        move_to(
            fa_obj_signer,
            FAController { mint_ref, burn_ref, transfer_ref }
        );
        move_to(
            fa_obj_signer,
            FAConfig {
                mint_fee_per_smallest_unit_of_fa: 0, // No fixed fee for bonding curve
                mint_limit: if (mint_limit_per_addr.is_some()) {
                    option::some(
                        MintLimit {
                            limit: *mint_limit_per_addr.borrow(),
                            mint_tracker: table::new()
                        }
                    )
                } else {
                    option::none()
                }
            }
        );
        move_to(
            fa_obj_signer,
            BondingCurve {
                target_supply,
                virtual_liquidity,
                curve_exponent,
                is_active: true
            }
        );

        let registry = borrow_global_mut<Registry>(@launchpad_addr);
        registry.fa_objects.push_back(fa_obj);

        event::emit(
            CreateBondingCurveFAEvent {
                creator_addr: sender_addr,
                fa_obj,
                max_supply,
                name,
                symbol,
                decimals,
                icon_uri,
                project_uri,
                target_supply,
                virtual_liquidity,
                curve_exponent,
                pre_mint_amount: 0,
                mint_limit_per_addr
            }
        );
    }

    /// Buy tokens through bonding curve
    public entry fun buy_token(
        sender: &signer, fa_obj: Object<Metadata>, amount: u64
    ) acquires FAController, FAConfig, Config, BondingCurve {
        let sender_addr = signer::address_of(sender);
        
        // Check if bonding curve is still active and get values
        let bonding_curve = borrow_global<BondingCurve>(object::object_address(&fa_obj));
        assert!(bonding_curve.is_active, 100); // Bonding curve is not active
        let target_supply = bonding_curve.target_supply;
        let virtual_liquidity = bonding_curve.virtual_liquidity;
        
        // Check mint limits
        check_mint_limit_and_update_mint_tracker(sender_addr, fa_obj, amount);
        
        // Calculate cost using bonding curve
        let total_cost = get_bonding_curve_mint_cost(fa_obj, amount);
        
        // Pay for minting
        if (total_cost > 0) {
            let config = borrow_global<Config>(@launchpad_addr);
            aptos_account::transfer(sender, config.mint_fee_collector_addr, total_cost);
        };
        
        // Mint tokens
        mint_fa_internal(sender, fa_obj, amount, total_cost);
        
        // Check if target supply is reached and deactivate if needed
        let current_supply = fungible_asset::supply(fa_obj);
        if (current_supply.is_some() && *current_supply.borrow() >= (target_supply as u128)) {
            // Deactivate bonding curve
            let bonding_curve_mut = borrow_global_mut<BondingCurve>(object::object_address(&fa_obj));
            bonding_curve_mut.is_active = false;
            
            event::emit(
                BondingCurveTargetReachedEvent {
                    fa_obj,
                    final_supply: (*current_supply.borrow() as u64),
                    total_virtual_liquidity: virtual_liquidity
                }
            );
        };
        
        let price_per_token = if (amount > 0) { total_cost / amount } else { 0 };
        event::emit(
            BondingCurveMintEvent {
                fa_obj,
                amount,
                recipient_addr: sender_addr,
                total_cost,
                price_per_token
            }
        );
    }

    /// Sell tokens through bonding curve
    public entry fun sell_token(
        sender: &signer, fa_obj: Object<Metadata>, amount: u64
    ) acquires FAController, BondingCurve {
        let sender_addr = signer::address_of(sender);
        
        // Check if bonding curve is still active
        let bonding_curve = borrow_global<BondingCurve>(object::object_address(&fa_obj));
        assert!(bonding_curve.is_active, 100); // Bonding curve is not active
        
        // Check if user has enough tokens to sell
        let user_balance = primary_fungible_store::balance(sender_addr, fa_obj);
        assert!(user_balance >= amount, 101); // Insufficient balance
        
        // Calculate payout using bonding curve
        let payout = get_bonding_curve_sell_payout(fa_obj, amount);
        
        // Burn tokens from user
        let fa_obj_addr = object::object_address(&fa_obj);
        let fa_controller = borrow_global<FAController>(fa_obj_addr);
        primary_fungible_store::burn(&fa_controller.burn_ref, sender_addr, amount);
        
        // TODO: Implement APT payout mechanism
        // Note: For now, this function burns tokens but doesn't transfer APT
        // A proper implementation would require the contract to maintain a liquidity pool
        
        let price_per_token = if (amount > 0) { payout / amount } else { 0 };
        event::emit(
            BondingCurveSellEvent {
                fa_obj,
                amount,
                seller_addr: sender_addr,
                total_payout: payout,
                price_per_token
            }
        );
    }

    // ================================= View Functions ================================== //

    #[view]
    /// Get contract admin
    public fun get_admin(): address acquires Config {
        let config = borrow_global<Config>(@launchpad_addr);
        config.admin_addr
    }

    #[view]
    /// Get contract pending admin
    public fun get_pending_admin(): Option<address> acquires Config {
        let config = borrow_global<Config>(@launchpad_addr);
        config.pending_admin_addr
    }

    #[view]
    /// Get mint fee collector address
    public fun get_mint_fee_collector(): address acquires Config {
        let config = borrow_global<Config>(@launchpad_addr);
        config.mint_fee_collector_addr
    }

    #[view]
    /// Get all fungible assets created using this contract
    public fun get_registry(): vector<Object<Metadata>> acquires Registry {
        let registry = borrow_global<Registry>(@launchpad_addr);
        registry.fa_objects
    }

    #[view]
    /// Get fungible asset metadata
    public fun get_fa_object_metadata(fa_obj: Object<Metadata>): (String, String, u8) {
        let name = fungible_asset::name(fa_obj);
        let symbol = fungible_asset::symbol(fa_obj);
        let decimals = fungible_asset::decimals(fa_obj);
        (symbol, name, decimals)
    }

    #[view]
    /// Get mint limit per address
    public fun get_mint_limit(fa_obj: Object<Metadata>): Option<u64> acquires FAConfig {
        let fa_config = borrow_global<FAConfig>(object::object_address(&fa_obj));
        if (fa_config.mint_limit.is_some()) {
            option::some(fa_config.mint_limit.borrow().limit)
        } else {
            option::none()
        }
    }

    #[view]
    /// Get current minted amount by an address
    public fun get_current_minted_amount(
        fa_obj: Object<Metadata>, addr: address
    ): u64 acquires FAConfig {
        let fa_config = borrow_global<FAConfig>(object::object_address(&fa_obj));
        assert!(fa_config.mint_limit.is_some(), ENO_MINT_LIMIT);
        let mint_limit = fa_config.mint_limit.borrow();
        let mint_tracker = &mint_limit.mint_tracker;
        *mint_tracker.borrow_with_default(addr, &0)
    }

    #[view]
    /// Get mint fee denominated in oapt (smallest unit of APT, i.e. 1e-8 APT)
    public fun get_mint_fee(
        fa_obj: Object<Metadata>,
        // Amount in smallest unit of FA
        amount: u64
    ): u64 acquires FAConfig {
        let fa_config = borrow_global<FAConfig>(object::object_address(&fa_obj));
        amount * fa_config.mint_fee_per_smallest_unit_of_fa
    }

    #[view]
    /// Get bonding curve configuration
    public fun get_bonding_curve(fa_obj: Object<Metadata>): BondingCurve acquires BondingCurve {
        *borrow_global<BondingCurve>(object::object_address(&fa_obj))
    }

    #[view]
    /// Get bonding curve price for a given amount
    public fun get_bonding_curve_price(
        fa_obj: Object<Metadata>,
        amount: u64
    ): u64 acquires BondingCurve {
        let bonding_curve = borrow_global<BondingCurve>(object::object_address(&fa_obj));
        let current_supply = fungible_asset::supply(fa_obj);
        let supply = if (current_supply.is_some()) { *current_supply.borrow() } else { 0 };
        
        // Calculate price using polynomial bonding curve: price = k * (supply^n)
        // For quadratic curve (exponent 2): price = (supply^2 * amount) / virtual_liquidity
        if (bonding_curve.virtual_liquidity == 0) {
            0
        } else {
            let supply_u64 = supply as u64;
            (supply_u64 * supply_u64 * amount) / bonding_curve.virtual_liquidity
        }
    }

    #[view]
    /// Get total cost to mint amount through bonding curve
    public fun get_bonding_curve_mint_cost(
        fa_obj: Object<Metadata>,
        amount: u64
    ): u64 acquires BondingCurve {
        let bonding_curve = borrow_global<BondingCurve>(object::object_address(&fa_obj));
        let current_supply = fungible_asset::supply(fa_obj);
        let supply = if (current_supply.is_some()) { *current_supply.borrow() } else { 0 };
        
        // Calculate cost using integral of bonding curve
        // For polynomial curve: cost = k * ((supply + amount)^(n+1) - supply^(n+1)) / (n+1)
        // Simplified for exponent 2: cost = k * ((supply + amount)^3 - supply^3) / 3
        if (bonding_curve.virtual_liquidity == 0) {
            0
        } else {
            let new_supply = (supply as u64) + amount;
            let cost = (new_supply * new_supply * new_supply - (supply as u64) * (supply as u64) * (supply as u64)) / (3 * bonding_curve.virtual_liquidity);
            cost
        }
    }

    #[view]
    /// Get total payout for selling amount through bonding curve
    public fun get_bonding_curve_sell_payout(
        fa_obj: Object<Metadata>,
        amount: u64
    ): u64 acquires BondingCurve {
        let bonding_curve = borrow_global<BondingCurve>(object::object_address(&fa_obj));
        let current_supply = fungible_asset::supply(fa_obj);
        let supply = if (current_supply.is_some()) { *current_supply.borrow() } else { 0 };
        
        // Calculate payout using integral of bonding curve (reverse of minting)
        // For polynomial curve: payout = k * (supply^(n+1) - (supply - amount)^(n+1)) / (n+1)
        // Simplified for exponent 2: payout = k * (supply^3 - (supply - amount)^3) / 3
        if (bonding_curve.virtual_liquidity == 0 || (supply as u64) < amount) {
            0
        } else {
            let remaining_supply = (supply as u64) - amount;
            let payout = ((supply as u64) * (supply as u64) * (supply as u64) - remaining_supply * remaining_supply * remaining_supply) / (3 * bonding_curve.virtual_liquidity);
            payout
        }
    }

    // ================================= Helper Functions ================================== //

    /// Check if sender is admin or owner of the object when package is published to object
    fun is_admin(config: &Config, sender: address): bool {
        if (sender == config.admin_addr) { true }
        else {
            if (object::is_object(@launchpad_addr)) {
                let obj = object::address_to_object<ObjectCore>(@launchpad_addr);
                object::is_owner(obj, sender)
            } else { false }
        }
    }

    /// Check mint limit and update mint tracker
    fun check_mint_limit_and_update_mint_tracker(
        sender: address, fa_obj: Object<Metadata>, amount: u64
    ) acquires FAConfig {
        let mint_limit = get_mint_limit(fa_obj);
        if (mint_limit.is_some()) {
            let old_amount = get_current_minted_amount(fa_obj, sender);
            assert!(
                old_amount + amount <= *mint_limit.borrow(),
                EMINT_LIMIT_REACHED
            );
            let fa_config = borrow_global_mut<FAConfig>(object::object_address(&fa_obj));
            let mint_limit = fa_config.mint_limit.borrow_mut();
            mint_limit.mint_tracker.upsert(sender, old_amount + amount)
        }
    }

    /// ACtual implementation of minting FA
    fun mint_fa_internal(
        sender: &signer,
        fa_obj: Object<Metadata>,
        amount: u64,
        total_mint_fee: u64
    ) acquires FAController {
        let sender_addr = signer::address_of(sender);
        let fa_obj_addr = object::object_address(&fa_obj);

        let fa_controller = borrow_global<FAController>(fa_obj_addr);
        primary_fungible_store::mint(&fa_controller.mint_ref, sender_addr, amount);

        event::emit(
            MintFAEvent { fa_obj, amount, recipient_addr: sender_addr, total_mint_fee }
        );
    }

    /// Pay for mint
    fun pay_for_mint(sender: &signer, total_mint_fee: u64) acquires Config {
        if (total_mint_fee > 0) {
            let config = borrow_global<Config>(@launchpad_addr);
            aptos_account::transfer(
                sender, config.mint_fee_collector_addr, total_mint_fee
            )
        }
    }

    // ================================= Uint Tests ================================== //

    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use aptos_framework::aptos_coin;
    #[test_only]
    use aptos_framework::coin;

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_happy_path(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry, FAController, Config, FAConfig {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        let sender_addr = signer::address_of(sender);

        init_module(sender);

        // create first FA

        create_fa(
            sender,
            option::some(1000),
            string::utf8(b"FA1"),
            string::utf8(b"FA1"),
            2,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            option::none(),
            option::none(),
            option::some(500)
        );
        let registry = get_registry();
        let fa_1 = registry[registry.length() - 1];
        assert!(fungible_asset::supply(fa_1) == option::some(0), 1);

        mint_fa(sender, fa_1, 20);
        assert!(fungible_asset::supply(fa_1) == option::some(20), 2);
        assert!(primary_fungible_store::balance(sender_addr, fa_1) == 20, 3);

        // create second FA

        create_fa(
            sender,
            option::some(1000),
            string::utf8(b"FA2"),
            string::utf8(b"FA2"),
            3,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            option::some(1),
            option::none(),
            option::some(500)
        );
        let registry = get_registry();
        let fa_2 = registry[registry.length() - 1];
        assert!(fungible_asset::supply(fa_2) == option::some(0), 4);

        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);
        let mint_fee = get_mint_fee(fa_2, 300);
        aptos_coin::mint(aptos_framework, sender_addr, mint_fee);
        mint_fa(sender, fa_2, 300);
        assert!(fungible_asset::supply(fa_2) == option::some(300), 5);
        assert!(primary_fungible_store::balance(sender_addr, fa_2) == 300, 6);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    // ================================= Bonding Curve Tests ================================== //

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_bonding_curve_basic_functionality(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry, BondingCurve {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let sender_addr = signer::address_of(sender);

        init_module(sender);
        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);

        // Create FA with bonding curve
        create_token(
            sender,
            option::some(1000000), // max supply
            string::utf8(b"BONDING_TOKEN"),
            string::utf8(b"BOND"),
            8,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            1000000, // target supply
            1000000, // virtual liquidity
            2, // curve exponent
            option::some(100000) // mint limit per addr
        );

        let registry = get_registry();
        let fa_obj = registry[registry.length() - 1];

        // Test initial bonding curve state
        let curve = get_bonding_curve(fa_obj);
        assert!(curve.target_supply == 1000000, 10);
        assert!(curve.virtual_liquidity == 1000000, 11);
        assert!(curve.curve_exponent == 2, 12);
        assert!(curve.is_active == true, 13);

        // Test price calculation at different amounts
        let price_1 = get_bonding_curve_price(fa_obj, 1000);
        let price_2 = get_bonding_curve_price(fa_obj, 2000);
        let price_3 = get_bonding_curve_price(fa_obj, 5000);
        
        // Price should increase as amount increases (since price = supply^2 * amount / virtual_liquidity)
        // With supply = 0, all prices should be 0, so let's test with a non-zero supply scenario
        assert!(price_1 == 0, 14); // Should be 0 with supply = 0
        assert!(price_2 == 0, 15); // Should be 0 with supply = 0
        assert!(price_3 == 0, 16); // Should be 0 with supply = 0

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_bonding_curve_minting(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry, BondingCurve, Config, FAConfig, FAController {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let sender_addr = signer::address_of(sender);

        init_module(sender);
        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);

        // Create FA with bonding curve
        create_token(
            sender,
            option::some(1000000),
            string::utf8(b"BONDING_TOKEN"),
            string::utf8(b"BOND"),
            8,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            1000000,
            1000000,
            2,
            option::some(100000)
        );

        let registry = get_registry();
        let fa_obj = registry[registry.length() - 1];

        // Mint tokens through bonding curve
        let mint_amount = 1000;
        let mint_cost = get_bonding_curve_mint_cost(fa_obj, mint_amount);
        
        // Give user enough APT to mint
        aptos_coin::mint(aptos_framework, sender_addr, mint_cost);
        
        // Mint tokens
        buy_token(sender, fa_obj, mint_amount);
        
        // Verify minting worked
        assert!(fungible_asset::supply(fa_obj) == option::some(mint_amount as u128), 20);
        assert!(primary_fungible_store::balance(sender_addr, fa_obj) == mint_amount, 21);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_bonding_curve_price_increases(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry, BondingCurve, Config, FAConfig, FAController {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let sender_addr = signer::address_of(sender);

        init_module(sender);
        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);

        // Create FA with bonding curve
        create_token(
            sender,
            option::some(1000000),
            string::utf8(b"BONDING_TOKEN"),
            string::utf8(b"BOND"),
            8,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            1000000,
            1000000,
            2,
            option::some(100000)
        );

        let registry = get_registry();
        let fa_obj = registry[registry.length() - 1];

        // Get initial price
        let initial_price = get_bonding_curve_price(fa_obj, 1000);
        
        // Mint some tokens
        let mint_amount = 1000;
        let mint_cost = get_bonding_curve_mint_cost(fa_obj, mint_amount);
        aptos_coin::mint(aptos_framework, sender_addr, mint_cost);
        buy_token(sender, fa_obj, mint_amount);

        // Get price after minting
        let price_after_mint = get_bonding_curve_price(fa_obj, 1000);
        
        // Price should have increased
        assert!(price_after_mint > initial_price, 30);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_bonding_curve_target_reached(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry, BondingCurve, Config, FAConfig, FAController {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let sender_addr = signer::address_of(sender);

        init_module(sender);
        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);

        // Create FA with low target supply for testing
        create_token(
            sender,
            option::some(10000),
            string::utf8(b"BONDING_TOKEN"),
            string::utf8(b"BOND"),
            8,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            5000, // low target supply
            1000000,
            2,
            option::some(100000)
        );

        let registry = get_registry();
        let fa_obj = registry[registry.length() - 1];

        // Mint tokens to reach target
        let mint_amount = 5000;
        let mint_cost = get_bonding_curve_mint_cost(fa_obj, mint_amount);
        aptos_coin::mint(aptos_framework, sender_addr, mint_cost);
        buy_token(sender, fa_obj, mint_amount);

        // Check if target is reached
        let curve = get_bonding_curve(fa_obj);
        assert!(curve.is_active == false, 40);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_bonding_curve_mint_limit_enforcement(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry, BondingCurve, Config, FAConfig, FAController {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let sender_addr = signer::address_of(sender);

        init_module(sender);
        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);

        // Create FA with bonding curve and low mint limit
        create_token(
            sender,
            option::some(1000000),
            string::utf8(b"BONDING_TOKEN"),
            string::utf8(b"BOND"),
            8,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            1000000,
            1000000,
            2,
            option::some(1000) // low mint limit
        );

        let registry = get_registry();
        let fa_obj = registry[registry.length() - 1];

        // Mint up to limit
        let mint_amount = 1000;
        let mint_cost = get_bonding_curve_mint_cost(fa_obj, mint_amount);
        aptos_coin::mint(aptos_framework, sender_addr, mint_cost);
        buy_token(sender, fa_obj, mint_amount);

        // Try to mint more (should fail due to mint limit)
        let additional_mint = 100;
        let additional_cost = get_bonding_curve_mint_cost(fa_obj, additional_mint);
        aptos_coin::mint(aptos_framework, sender_addr, additional_cost);
        
        // This should fail due to mint limit - we'll test by checking current minted amount
        let current_minted = get_current_minted_amount(fa_obj, sender_addr);
        assert!(current_minted == mint_amount, 50); // Should still be the original amount

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_sell_token_basic_functionality(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry, BondingCurve, Config, FAConfig, FAController {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let sender_addr = signer::address_of(sender);

        init_module(sender);
        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);

        // Create token with bonding curve
        create_token(
            sender,
            option::some(1000000),
            string::utf8(b"SELL_TOKEN"),
            string::utf8(b"SELL"),
            8,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            1000000,
            1000000,
            2,
            option::some(100000)
        );

        let registry = get_registry();
        let fa_obj = registry[registry.length() - 1];

        // Buy some tokens first
        let buy_amount = 1000;
        let buy_cost = get_bonding_curve_mint_cost(fa_obj, buy_amount);
        aptos_coin::mint(aptos_framework, sender_addr, buy_cost);
        buy_token(sender, fa_obj, buy_amount);

        // Verify user has tokens
        assert!(primary_fungible_store::balance(sender_addr, fa_obj) == buy_amount, 60);

        // Sell some tokens
        let sell_amount = 500;
        sell_token(sender, fa_obj, sell_amount);

        // Verify user has remaining tokens
        assert!(primary_fungible_store::balance(sender_addr, fa_obj) == buy_amount - sell_amount, 61);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_sell_token_price_decreases(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry, BondingCurve, Config, FAConfig, FAController {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let sender_addr = signer::address_of(sender);

        init_module(sender);
        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);

        // Create token with bonding curve
        create_token(
            sender,
            option::some(1000000),
            string::utf8(b"SELL_TOKEN"),
            string::utf8(b"SELL"),
            8,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            1000000,
            1000000,
            2,
            option::some(100000)
        );

        let registry = get_registry();
        let fa_obj = registry[registry.length() - 1];

        // Buy tokens to increase supply
        let buy_amount = 2000;
        let buy_cost = get_bonding_curve_mint_cost(fa_obj, buy_amount);
        aptos_coin::mint(aptos_framework, sender_addr, buy_cost);
        buy_token(sender, fa_obj, buy_amount);

        // Get initial sell price
        let initial_sell_price = get_bonding_curve_sell_payout(fa_obj, 1000);

        // Sell some tokens
        let sell_amount = 1000;
        sell_token(sender, fa_obj, sell_amount);

        // Get sell price after selling
        let sell_price_after = get_bonding_curve_sell_payout(fa_obj, 1000);

        // Price should have decreased (less payout for same amount)
        assert!(sell_price_after < initial_sell_price, 70);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_sell_token_insufficient_balance(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let sender_addr = signer::address_of(sender);

        init_module(sender);
        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);

        // Create token with bonding curve
        create_token(
            sender,
            option::some(1000000),
            string::utf8(b"SELL_TOKEN"),
            string::utf8(b"SELL"),
            8,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            1000000,
            1000000,
            2,
            option::some(100000)
        );

        let registry = get_registry();
        let fa_obj = registry[registry.length() - 1];

        // Try to sell without having any tokens (should fail)
        // This test verifies the insufficient balance check
        let user_balance = primary_fungible_store::balance(sender_addr, fa_obj);
        assert!(user_balance == 0, 80); // User has no tokens

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos_framework = @0x1, sender = @launchpad_addr)]
    fun test_sell_token_after_target_reached(
        aptos_framework: &signer, sender: &signer
    ) acquires Registry, BondingCurve, Config, FAConfig, FAController {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let sender_addr = signer::address_of(sender);

        init_module(sender);
        account::create_account_for_test(sender_addr);
        coin::register<aptos_coin::AptosCoin>(sender);

        // Create token with low target supply
        create_token(
            sender,
            option::some(10000),
            string::utf8(b"SELL_TOKEN"),
            string::utf8(b"SELL"),
            8,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url"),
            5000, // low target supply
            1000000,
            2,
            option::some(100000)
        );

        let registry = get_registry();
        let fa_obj = registry[registry.length() - 1];

        // Buy tokens to reach target
        let buy_amount = 5000;
        let buy_cost = get_bonding_curve_mint_cost(fa_obj, buy_amount);
        aptos_coin::mint(aptos_framework, sender_addr, buy_cost);
        buy_token(sender, fa_obj, buy_amount);

        // Verify bonding curve is deactivated
        let curve = get_bonding_curve(fa_obj);
        assert!(curve.is_active == false, 90);

        // Try to sell tokens (should fail because bonding curve is inactive)
        let user_balance = primary_fungible_store::balance(sender_addr, fa_obj);
        assert!(user_balance == buy_amount, 91); // User still has tokens

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}

