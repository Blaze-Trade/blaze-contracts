module quest_staking_addr::quest_staking {
    use std::signer;
    use std::string::String;
    use std::vector;
    use std::option::{Self, Option};
    use std::error;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use aptos_framework::event;

    // ================================= Errors ================================= //
    /// Only admin can create quests
    const ERR_ONLY_ADMIN_CAN_CREATE_QUEST: u64 = 1;
    /// Only admin can declare winner
    const ERR_ONLY_ADMIN_CAN_DECLARE_WINNER: u64 = 2;
    /// Quest does not exist
    const ERR_QUEST_DOES_NOT_EXIST: u64 = 3;
    /// User already participated in this quest
    const ERR_USER_ALREADY_PARTICIPATED: u64 = 4;
    /// Quest is not active
    const ERR_QUEST_NOT_ACTIVE: u64 = 5;
    /// Quest is not ready for result declaration
    const ERR_QUEST_NOT_READY_FOR_RESULT: u64 = 6;
    /// Invalid entry fee (must be > 0)
    const ERR_INVALID_ENTRY_FEE: u64 = 7;
    /// Invalid time parameters
    const ERR_INVALID_TIME_PARAMETERS: u64 = 8;
    /// Invalid portfolio size (must be 1-5 tokens)
    const ERR_INVALID_PORTFOLIO_SIZE: u64 = 9;
    /// User has not participated in this quest
    const ERR_USER_NOT_PARTICIPATED: u64 = 10;
    /// Winner is not a participant
    const ERR_WINNER_NOT_PARTICIPANT: u64 = 11;

    // ================================= Data Structures ================================= //

    /// Quest status enum
    public enum QuestStatus has store, copy, drop {
        Active,      // Accepting participants
        Closed,      // No more participants, waiting for results
        Completed,   // Winner declared, rewards distributed
        Cancelled,   // Quest cancelled, refunds processed
    }

    /// Token selection in portfolio
    public struct TokenSelection has store, copy, drop {
        token_address: address,
        amount_usdc: u64, // Amount in USDC (6 decimals)
    }

    /// User portfolio selection
    public struct Portfolio has store, copy, drop {
        tokens: vector<TokenSelection>,
        total_value_usdc: u64,
        selected_at: u64,
    }

    /// Quest information
    public struct Quest has key, store, copy, drop {
        quest_id: u64,
        name: String,
        admin: address,
        entry_fee: u64,           // in APT (octas)
        buy_in_time: u64,          // timestamp when quest closes for new participants
        result_time: u64,          // timestamp when results can be declared
        status: QuestStatus,
        participants: vector<address>,
        total_pool: u64,
        winner: Option<address>,
        created_at: u64,
    }

    /// User participation record
    public struct Participation has key, store, copy, drop {
        quest_id: u64,
        user: address,
        portfolio: Option<Portfolio>,
        entry_fee_paid: u64,
        joined_at: u64,
    }

    /// Global quest registry
    struct QuestRegistry has key, store {
        quests: vector<Quest>,
        next_quest_id: u64,
    }

    /// Admin configuration
    struct AdminConfig has key, store {
        admin: address,
    }

    // ================================= Events ================================= //

    #[event]
    struct QuestCreatedEvent has drop, store {
        quest_id: u64,
        name: String,
        admin: address,
        entry_fee: u64,
        buy_in_time: u64,
        result_time: u64,
    }

    #[event]
    struct QuestJoinedEvent has drop, store {
        quest_id: u64,
        user: address,
        entry_fee: u64,
    }

    #[event]
    struct PortfolioSelectedEvent has drop, store {
        quest_id: u64,
        user: address,
        portfolio_size: u64,
        total_value_usdc: u64,
    }

    #[event]
    struct WinnerDeclaredEvent has drop, store {
        quest_id: u64,
        winner: address,
        total_reward: u64,
    }

    // ================================= Initialization ================================= //

    /// Initialize the quest staking module
    fun init_module(sender: &signer) {
        let sender_addr = signer::address_of(sender);
        
        // Store admin configuration
        move_to(sender, AdminConfig {
            admin: sender_addr,
        });

        // Initialize quest registry
        move_to(sender, QuestRegistry {
            quests: vector::empty(),
            next_quest_id: 1,
        });
    }

    // ================================= Admin Functions ================================= //

    /// Create a new quest (admin only)
    public entry fun create_quest(
        admin: &signer,
        name: String,
        entry_fee: u64,
        buy_in_time: u64,
        result_time: u64,
    ) acquires AdminConfig, QuestRegistry {
        // Verify admin
        let admin_config = borrow_global<AdminConfig>(@quest_staking_addr);
        assert!(signer::address_of(admin) == admin_config.admin, error::permission_denied(ERR_ONLY_ADMIN_CAN_CREATE_QUEST));

        // Validate parameters
        assert!(entry_fee > 0, error::invalid_argument(ERR_INVALID_ENTRY_FEE));
        assert!(result_time > buy_in_time, error::invalid_argument(ERR_INVALID_TIME_PARAMETERS));

        let current_time = timestamp::now_seconds();
        let buy_in_timestamp = current_time + buy_in_time;
        let result_timestamp = current_time + result_time;

        // Get quest registry
        let quest_registry = borrow_global_mut<QuestRegistry>(@quest_staking_addr);
        let quest_id = quest_registry.next_quest_id;

        // Create new quest
        let new_quest = Quest {
            quest_id,
            name,
            admin: signer::address_of(admin),
            entry_fee,
            buy_in_time: buy_in_timestamp,
            result_time: result_timestamp,
            status: QuestStatus::Active,
            participants: vector::empty(),
            total_pool: 0,
            winner: option::none(),
            created_at: current_time,
        };

        // Add quest to registry
        quest_registry.quests.push_back(new_quest);
        quest_registry.next_quest_id = quest_registry.next_quest_id + 1;

        // Emit event
        event::emit(QuestCreatedEvent {
            quest_id,
            name,
            admin: signer::address_of(admin),
            entry_fee,
            buy_in_time: buy_in_timestamp,
            result_time: result_timestamp,
        });
    }

    /// Declare winner and distribute rewards (admin only)
    public entry fun declare_winner(
        admin: &signer,
        quest_id: u64,
        winner: address,
    ) acquires AdminConfig, QuestRegistry {
        // Verify admin
        let admin_config = borrow_global<AdminConfig>(@quest_staking_addr);
        assert!(signer::address_of(admin) == admin_config.admin, error::permission_denied(ERR_ONLY_ADMIN_CAN_DECLARE_WINNER));

        // Get quest
        let quest_registry = borrow_global_mut<QuestRegistry>(@quest_staking_addr);
        assert!(quest_id > 0 && quest_id <= quest_registry.quests.length(), error::not_found(ERR_QUEST_DOES_NOT_EXIST));
        
        let quest = quest_registry.quests.borrow_mut(quest_id - 1);
        
        // Verify quest is ready for result
        let current_time = timestamp::now_seconds();
        assert!(current_time >= quest.result_time, error::invalid_state(ERR_QUEST_NOT_READY_FOR_RESULT));
        assert!(quest.status == QuestStatus::Active || quest.status == QuestStatus::Closed, error::invalid_state(ERR_QUEST_NOT_READY_FOR_RESULT));

        // Verify winner is a participant
        assert!(vector::contains(&quest.participants, &winner), error::invalid_argument(ERR_WINNER_NOT_PARTICIPANT));

        // Update quest status
        quest.status = QuestStatus::Completed;
        quest.winner = option::some(winner);

        // Distribute rewards
        if (quest.total_pool > 0) {
            let admin_coin = coin::withdraw<AptosCoin>(admin, quest.total_pool);
            coin::deposit(winner, admin_coin);
        };

        // Emit event
        event::emit(WinnerDeclaredEvent {
            quest_id,
            winner,
            total_reward: quest.total_pool,
        });
    }

    // ================================= User Functions ================================= //

    /// Join a quest by paying entry fee
    public entry fun join_quest(
        user: &signer,
        quest_id: u64,
    ) acquires QuestRegistry {
        let user_addr = signer::address_of(user);

        // Get quest
        let quest_registry = borrow_global_mut<QuestRegistry>(@quest_staking_addr);
        assert!(quest_id > 0 && quest_id <= quest_registry.quests.length(), error::not_found(ERR_QUEST_DOES_NOT_EXIST));
        
        let quest = quest_registry.quests.borrow_mut(quest_id - 1);

        // Verify quest is active
        assert!(quest.status == QuestStatus::Active, error::invalid_state(ERR_QUEST_NOT_ACTIVE));

        // Verify user hasn't already participated
        let participation_addr = get_participation_address(user_addr, quest_id);
        assert!(!exists<Participation>(participation_addr), error::invalid_argument(ERR_USER_ALREADY_PARTICIPATED));

        // Verify quest is still accepting participants
        let current_time = timestamp::now_seconds();
        assert!(current_time < quest.buy_in_time, error::invalid_state(ERR_QUEST_NOT_ACTIVE));

        // Transfer entry fee from user to admin (contract admin holds the pool)
        let entry_fee_coin = coin::withdraw<AptosCoin>(user, quest.entry_fee);
        coin::deposit(quest.admin, entry_fee_coin);

        // Create participation record
        let participation = Participation {
            quest_id,
            user: user_addr,
            portfolio: option::none(),
            entry_fee_paid: quest.entry_fee,
            joined_at: current_time,
        };

        // Store participation
        move_to(user, participation);

        // Update quest
        quest.participants.push_back(user_addr);
        quest.total_pool = quest.total_pool + quest.entry_fee;

        // Emit event
        event::emit(QuestJoinedEvent {
            quest_id,
            user: user_addr,
            entry_fee: quest.entry_fee,
        });
    }

    /// Select portfolio for a quest
    public entry fun select_portfolio(
        user: &signer,
        quest_id: u64,
        token_addresses: vector<address>,
        amounts_usdc: vector<u64>,
    ) acquires Participation {
        let user_addr = signer::address_of(user);

        // Validate portfolio size
        let portfolio_size = vector::length(&token_addresses);
        assert!(portfolio_size >= 1 && portfolio_size <= 5, error::invalid_argument(ERR_INVALID_PORTFOLIO_SIZE));
        assert!(portfolio_size == vector::length(&amounts_usdc), error::invalid_argument(ERR_INVALID_PORTFOLIO_SIZE));

        // Get participation
        let participation_addr = get_participation_address(user_addr, quest_id);
        assert!(exists<Participation>(participation_addr), error::not_found(ERR_USER_NOT_PARTICIPATED));
        
        let participation = borrow_global_mut<Participation>(participation_addr);

        // Create token selections
        let tokens = vector::empty<TokenSelection>();
        let total_value = 0;
        let i = 0;
        while (i < portfolio_size) {
            let token_address = *vector::borrow(&token_addresses, i);
            let amount_usdc = *vector::borrow(&amounts_usdc, i);
            
            vector::push_back(&mut tokens, TokenSelection {
                token_address,
                amount_usdc,
            });
            
            total_value = total_value + amount_usdc;
            i = i + 1;
        };

        // Create portfolio
        let portfolio = Portfolio {
            tokens,
            total_value_usdc: total_value,
            selected_at: timestamp::now_seconds(),
        };

        // Update participation
        participation.portfolio = option::some(portfolio);

        // Emit event
        event::emit(PortfolioSelectedEvent {
            quest_id,
            user: user_addr,
            portfolio_size,
            total_value_usdc: total_value,
        });
    }

    /// Create Active status
    public fun create_active_status(): QuestStatus {
        QuestStatus::Active
    }

    /// Create Completed status
    public fun create_completed_status(): QuestStatus {
        QuestStatus::Completed
    }

    /// Create Closed status
    public fun create_closed_status(): QuestStatus {
        QuestStatus::Closed
    }

    /// Create Cancelled status
    public fun create_cancelled_status(): QuestStatus {
        QuestStatus::Cancelled
    }

    // ================================= Getter Functions ================================= //

    /// Get quest ID
    public fun get_quest_id(quest: &Quest): u64 {
        quest.quest_id
    }

    /// Get quest name
    public fun get_quest_name(quest: &Quest): String {
        quest.name
    }

    /// Get quest admin
    public fun get_quest_admin(quest: &Quest): address {
        quest.admin
    }

    /// Get quest entry fee
    public fun get_quest_entry_fee(quest: &Quest): u64 {
        quest.entry_fee
    }

    /// Get quest buy-in time
    public fun get_quest_buy_in_time(quest: &Quest): u64 {
        quest.buy_in_time
    }

    /// Get quest result time
    public fun get_quest_result_time(quest: &Quest): u64 {
        quest.result_time
    }

    /// Get quest status
    public fun get_quest_status(quest: &Quest): QuestStatus {
        quest.status
    }

    /// Get quest total pool
    public fun get_quest_total_pool(quest: &Quest): u64 {
        quest.total_pool
    }

    /// Get quest participants
    public fun get_quest_participants_list(quest: &Quest): vector<address> {
        quest.participants
    }

    /// Get quest winner
    public fun get_quest_winner(quest: &Quest): Option<address> {
        quest.winner
    }

    /// Get participation quest ID
    public fun get_participation_quest_id(participation: &Participation): u64 {
        participation.quest_id
    }

    /// Get participation user
    public fun get_participation_user(participation: &Participation): address {
        participation.user
    }

    /// Get participation entry fee paid
    public fun get_participation_entry_fee_paid(participation: &Participation): u64 {
        participation.entry_fee_paid
    }

    /// Get participation portfolio
    public fun get_participation_portfolio(participation: &Participation): Option<Portfolio> {
        participation.portfolio
    }

    /// Get portfolio tokens
    public fun get_portfolio_tokens(portfolio: &Portfolio): vector<TokenSelection> {
        portfolio.tokens
    }

    /// Get portfolio total value
    public fun get_portfolio_total_value_usdc(portfolio: &Portfolio): u64 {
        portfolio.total_value_usdc
    }

    // ================================= View Functions ================================= //

    #[view]
    public fun get_quest_info(quest_id: u64): Quest acquires QuestRegistry {
        let quest_registry = borrow_global<QuestRegistry>(@quest_staking_addr);
        assert!(quest_id > 0 && quest_id <= quest_registry.quests.length(), error::not_found(ERR_QUEST_DOES_NOT_EXIST));
        *quest_registry.quests.borrow(quest_id - 1)
    }

    #[view]
    public fun get_user_participation(user: address, quest_id: u64): Participation acquires Participation {
        let participation_addr = get_participation_address(user, quest_id);
        assert!(exists<Participation>(participation_addr), error::not_found(ERR_USER_NOT_PARTICIPATED));
        *borrow_global<Participation>(participation_addr)
    }

    #[view]
    public fun has_user_participated(user: address, quest_id: u64): bool {
        let participation_addr = get_participation_address(user, quest_id);
        exists<Participation>(participation_addr)
    }

    #[view]
    public fun get_all_quests(): vector<Quest> acquires QuestRegistry {
        let quest_registry = borrow_global<QuestRegistry>(@quest_staking_addr);
        let quests = vector::empty();
        let i = 0;
        while (i < quest_registry.quests.length()) {
            vector::push_back(&mut quests, *quest_registry.quests.borrow(i));
            i = i + 1;
        };
        quests
    }

    #[view]
    public fun get_quest_participants(quest_id: u64): vector<address> acquires QuestRegistry {
        let quest_registry = borrow_global<QuestRegistry>(@quest_staking_addr);
        assert!(quest_id > 0 && quest_id <= quest_registry.quests.length(), error::not_found(ERR_QUEST_DOES_NOT_EXIST));
        let quest = quest_registry.quests.borrow(quest_id - 1);
        let participants = vector::empty();
        let i = 0;
        while (i < quest.participants.length()) {
            vector::push_back(&mut participants, *quest.participants.borrow(i));
            i = i + 1;
        };
        participants
    }

    // ================================= Helper Functions ================================= //

    /// Get participation address for a user and quest
    fun get_participation_address(user: address, quest_id: u64): address {
        // Use a deterministic address based on user and quest_id
        // This is a simplified approach - in production, you might want to use object addresses
        user
    }

    // ================================= Test Functions ================================= //

    #[test_only]
    public fun init_module_for_test(sender: &signer) {
        init_module(sender);
    }
}
