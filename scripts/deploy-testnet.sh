#!/bin/bash

# Blaze Launchpad V2 - Testnet Deployment Script
# This script deploys the launchpad_v2 contract to Aptos testnet

set -e

echo "🚀 Blaze Launchpad V2 - Testnet Deployment"
echo "==========================================="
echo ""

# Check if aptos CLI is installed
if ! command -v aptos &> /dev/null; then
    echo "❌ Error: Aptos CLI is not installed"
    echo "Install it from: https://aptos.dev/tools/aptos-cli/install-cli/"
    exit 1
fi

echo "✅ Aptos CLI found"
echo ""

# Initialize testnet profile if it doesn't exist
echo "📝 Setting up testnet profile..."
if ! aptos config show-profiles | grep -q "testnet"; then
    echo "Creating new testnet profile..."
    aptos init --profile testnet --network testnet --skip-faucet
else
    echo "✅ Testnet profile already exists"
fi

echo ""
# Get profile name (default: testnet)
PROFILE=${APTOS_PROFILE:-testnet}
echo "📍 Using profile: $PROFILE"

# Get account address (remove quotes and comma, add 0x prefix if missing)
ACCOUNT_ADDRESS=$(aptos config show-profiles --profile $PROFILE | grep "account" | awk '{print $2}' | tr -d '",')
# Add 0x prefix if not present
if [[ ! $ACCOUNT_ADDRESS == 0x* ]]; then
    ACCOUNT_ADDRESS="0x${ACCOUNT_ADDRESS}"
fi
echo "📍 Account address: $ACCOUNT_ADDRESS"
echo ""

# Fund the account from testnet faucet
echo "💰 Funding account from testnet faucet..."
aptos account fund-with-faucet --profile $PROFILE --account $ACCOUNT_ADDRESS --amount 500000000 || echo "⚠️  Faucet might be rate-limited, continuing anyway..."
echo ""

# Check balance
echo "💳 Checking account balance..."
aptos account list --profile $PROFILE --account $ACCOUNT_ADDRESS
echo ""

# Compile the contract
echo "🔨 Compiling contract..."
cd move
aptos move compile --named-addresses blaze_token_launchpad=$ACCOUNT_ADDRESS
echo ""

# Test the contract
echo "🧪 Running tests..."
aptos move test --filter launchpad_v2
echo ""

# Deploy the contract
echo "📦 Deploying to testnet..."
echo "⚠️  You will be prompted to confirm the transaction"
aptos move publish \
    --profile $PROFILE \
    --named-addresses blaze_token_launchpad=$ACCOUNT_ADDRESS \
    --assume-yes

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Contract Details:"
echo "   Network: Testnet"
echo "   Account: $ACCOUNT_ADDRESS"
echo "   Module: ${ACCOUNT_ADDRESS}::launchpad_v2"
echo ""
echo "🔗 View on Explorer:"
echo "   https://explorer.aptoslabs.com/account/$ACCOUNT_ADDRESS?network=testnet"
echo ""
echo "📝 Save these details for testing!"
