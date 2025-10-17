#!/bin/bash

# Blaze Launchpad V2 - Testnet Testing Script
# This script tests the deployed contract on Aptos testnet
# Usage: ./test-contract.sh [profile_name]
# Example: ./test-contract.sh blazev2-testnet
# Or set via env: APTOS_PROFILE=blazev2-testnet ./test-contract.sh

set -e

echo "🧪 Blaze Launchpad V2 - Contract Testing"
echo "========================================"
echo ""

# Get profile name (from argument, env var, or default to testnet)
PROFILE=${1:-${APTOS_PROFILE:-blazev2-testnet}}
echo "📍 Using profile: $PROFILE"

# Get contract address (remove quotes and comma, add 0x prefix if missing)
ACCOUNT_ADDRESS=$(aptos config show-profiles --profile $PROFILE | grep "account" | awk '{print $2}' | tr -d '",')
# Add 0x prefix if not present
if [[ ! $ACCOUNT_ADDRESS == 0x* ]]; then
    ACCOUNT_ADDRESS="0x${ACCOUNT_ADDRESS}"
fi
echo "📍 Contract address: $ACCOUNT_ADDRESS"
echo ""

# Menu for testing different functions
echo "Select a function to test:"
echo "1. Get Admin Address"
echo "2. Get Treasury Address"
echo "3. Get Oracle Data"
echo "4. Get APT/USD Price"
echo "5. Get All Pools"
echo "6. Get Pool Balance"
echo "7. Get Fees"
echo "8. Create a Test Pool (TypeScript Required)"
echo "9. Update Oracle Price (Admin)"
echo "10. View Account Resources"
echo "11. Exit"
echo ""
read -p "Enter your choice (1-11): " choice

case $choice in
    1)
        echo "📞 Calling get_admin()..."
        aptos move view \
            --profile $PROFILE \
            --function-id ${ACCOUNT_ADDRESS}::launchpad_v2::get_admin
        ;;
    2)
        echo "📞 Calling get_treasury()..."
        aptos move view \
            --profile $PROFILE \
            --function-id ${ACCOUNT_ADDRESS}::launchpad_v2::get_treasury
        ;;
    3)
        echo "📞 Calling get_oracle_data()..."
        aptos move view \
            --profile $PROFILE \
            --function-id ${ACCOUNT_ADDRESS}::launchpad_v2::get_oracle_data
        ;;
    4)
        echo "📞 Calling get_apt_usd_price()..."
        aptos move view \
            --profile $PROFILE \
            --function-id ${ACCOUNT_ADDRESS}::launchpad_v2::get_apt_usd_price
        ;;
    5)
        echo "📞 Calling get_pools()..."
        aptos move view \
            --profile $PROFILE \
            --function-id ${ACCOUNT_ADDRESS}::launchpad_v2::get_pools
        ;;
    6)
        echo "📞 Calling get_pool_balance()..."
        read -p "Enter pool object address: " pool_addr
        aptos move view \
            --profile $PROFILE \
            --function-id ${ACCOUNT_ADDRESS}::launchpad_v2::get_pool_balance \
            --args address:$pool_addr
        ;;
    7)
        echo "📞 Calling get_fees()..."
        aptos move view \
            --profile $PROFILE \
            --function-id ${ACCOUNT_ADDRESS}::launchpad_v2::get_fees
        ;;
    8)
        echo "🔨 Create a Test Pool"
        echo "════════════════════════════════════════════════"
        echo ""
        echo "⚠️  IMPORTANT: The Aptos CLI cannot call create_pool!"
        echo ""
        echo "📋 Reason:"
        echo "   The function uses Option<T> parameters which the CLI"
        echo "   does not support (only basic types like string, u64, etc.)"
        echo ""
        echo "✅ Solution: Use the TypeScript SDK script instead"
        echo ""
        echo "📝 Steps to create a pool:"
        echo "   1. cd scripts"
        echo "   2. npm install"
        echo "   3. npm run create-pool"
        echo ""
        echo "   OR directly:"
        echo "   ts-node scripts/create-pool.ts"
        echo ""
        echo "📚 See CLI_LIMITATIONS.md for detailed explanation"
        echo ""
        read -p "Press Enter to continue..."
        ;;
    9)
        echo "🔧 Updating oracle price (Admin only)..."
        read -p "Enter new APT/USD price in cents (e.g., 850 for $8.50): " price
        read -p "Enter oracle address (or press Enter for current account): " oracle_addr
        if [ -z "$oracle_addr" ]; then
            oracle_addr=$ACCOUNT_ADDRESS
        fi
        
        aptos move run \
            --profile $PROFILE \
            --function-id ${ACCOUNT_ADDRESS}::launchpad_v2::update_oracle_price \
            --args u64:$price address:$oracle_addr
        ;;
    10)
        echo "📦 Viewing account resources..."
        aptos account list \
            --profile $PROFILE \
            --account $ACCOUNT_ADDRESS
        ;;
    11)
        echo "👋 Exiting..."
        exit 0
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Test completed!"
