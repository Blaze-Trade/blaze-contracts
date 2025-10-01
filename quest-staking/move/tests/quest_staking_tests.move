#[test_only]
module quest_staking_addr::quest_staking_tests {
    use std::signer;
    use std::string;
    use std::option;
    use aptos_framework::timestamp;
    use aptos_framework::account;

    use quest_staking_addr::quest_staking;

    // Test constants
    const ENTRY_FEE: u64 = 100000000; // 1 APT in octas
    const BUY_IN_TIME: u64 = 3600; // 1 hour
    const RESULT_TIME: u64 = 7200; // 2 hours

    #[test(aptos_framework = @std, admin = @quest_staking_addr, alice = @0x1234)]
    fun test_create_quest(aptos_framework: &signer, admin: &signer, alice: &signer) {
        setup_test_environment(aptos_framework, admin, alice);
        
        // Create a quest
        quest_staking::create_quest(
            admin,
            string::utf8(b"Test Quest"),
            ENTRY_FEE,
            BUY_IN_TIME,
            RESULT_TIME
        );

        // Verify quest was created
        let quest_info = quest_staking::get_quest_info(1);
        assert!(quest_staking::get_quest_id(&quest_info) == 1, 1);
        assert!(quest_staking::get_quest_name(&quest_info) == string::utf8(b"Test Quest"), 2);
        assert!(quest_staking::get_quest_admin(&quest_info) == signer::address_of(admin), 3);
        assert!(quest_staking::get_quest_entry_fee(&quest_info) == ENTRY_FEE, 4);
        assert!(quest_staking::get_quest_status(&quest_info) == quest_staking::create_active_status(), 5);
    }

    #[test(aptos_framework = @std, admin = @quest_staking_addr, alice = @0x1234)]
    #[expected_failure(abort_code = 327681)]
    fun test_non_admin_cannot_create_quest(aptos_framework: &signer, admin: &signer, alice: &signer) {
        setup_test_environment(aptos_framework, admin, alice);
        
        // Alice tries to create a quest (should fail)
        quest_staking::create_quest(
            alice,
            string::utf8(b"Test Quest"),
            ENTRY_FEE,
            BUY_IN_TIME,
            RESULT_TIME
        );
    }

    #[test(aptos_framework = @std, admin = @quest_staking_addr, alice = @0x1234)]
    #[expected_failure(abort_code = 65543)]
    fun test_create_quest_with_zero_entry_fee(aptos_framework: &signer, admin: &signer, alice: &signer) {
        setup_test_environment(aptos_framework, admin, alice);
        
        // Create quest with zero entry fee (should fail)
        quest_staking::create_quest(
            admin,
            string::utf8(b"Test Quest"),
            0,
            BUY_IN_TIME,
            RESULT_TIME
        );
    }

    #[test(aptos_framework = @std, admin = @quest_staking_addr, alice = @0x1234)]
    #[expected_failure(abort_code = 393219)]
    fun test_join_nonexistent_quest(aptos_framework: &signer, admin: &signer, alice: &signer) {
        setup_test_environment(aptos_framework, admin, alice);
        
        // Alice tries to join quest that doesn't exist (should fail)
        quest_staking::join_quest(alice, 999);
    }

    #[test(aptos_framework = @std, admin = @quest_staking_addr, alice = @0x1234)]
    #[expected_failure(abort_code = 393226)]
    fun test_select_portfolio_without_participation(aptos_framework: &signer, admin: &signer, alice: &signer) {
        setup_test_environment(aptos_framework, admin, alice);
        
        // Create a quest
        quest_staking::create_quest(
            admin,
            string::utf8(b"Test Quest"),
            ENTRY_FEE,
            BUY_IN_TIME,
            RESULT_TIME
        );

        // Create portfolio with 3 tokens
        let token_addresses = vector[@0x1111, @0x2222, @0x3333];
        let amounts_usdc = vector[1000000, 2000000, 3000000]; // 1, 2, 3 USDC

        // Alice selects portfolio (without joining quest first - this should work for testing)
        quest_staking::select_portfolio(alice, 1, token_addresses, amounts_usdc);
    }

    #[test(aptos_framework = @std, admin = @quest_staking_addr, alice = @0x1234)]
    #[expected_failure(abort_code = 65545)]
    fun test_select_empty_portfolio(aptos_framework: &signer, admin: &signer, alice: &signer) {
        setup_test_environment(aptos_framework, admin, alice);
        
        // Create a quest
        quest_staking::create_quest(
            admin,
            string::utf8(b"Test Quest"),
            ENTRY_FEE,
            BUY_IN_TIME,
            RESULT_TIME
        );

        // Alice tries to select empty portfolio (should fail)
        quest_staking::select_portfolio(alice, 1, vector[], vector[]);
    }

    #[test(aptos_framework = @std, admin = @quest_staking_addr, alice = @0x1234)]
    #[expected_failure(abort_code = 65545)]
    fun test_select_too_many_tokens(aptos_framework: &signer, admin: &signer, alice: &signer) {
        setup_test_environment(aptos_framework, admin, alice);
        
        // Create a quest
        quest_staking::create_quest(
            admin,
            string::utf8(b"Test Quest"),
            ENTRY_FEE,
            BUY_IN_TIME,
            RESULT_TIME
        );

        // Create portfolio with 6 tokens (should fail)
        let token_addresses = vector[@0x1111, @0x2222, @0x3333, @0x4444, @0x5555, @0x6666];
        let amounts_usdc = vector[1000000, 2000000, 3000000, 4000000, 5000000, 6000000];

        quest_staking::select_portfolio(alice, 1, token_addresses, amounts_usdc);
    }

    // Helper functions for test setup
    fun setup_test_environment(aptos_framework: &signer, admin: &signer, alice: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test_secs(1000);

        // Initialize the quest staking module
        quest_staking::init_module_for_test(admin);

        // Create test accounts
        account::create_account_for_test(signer::address_of(alice));
    }
}