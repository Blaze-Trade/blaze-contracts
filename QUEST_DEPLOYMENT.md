# Quest Staking Contract Deployment Guide

## Prerequisites

1. **Aptos CLI installed**: Make sure you have the Aptos CLI installed
2. **Account funded**: Your devnet account needs APT for transaction fees
3. **Node.js**: Required for running the deployment script

## Step-by-Step Deployment

### 1. Fund Your Account (if needed)

```bash
# Fund your quest_staking account
aptos account fund-with-faucet --profile quest_staking
```

### 2. Compile the Contract

```bash
# Navigate to the quest-staking directory
cd quest-staking/move

# Compile the contract
aptos move compile --profile quest_staking
```

### 3. Run Tests (Optional but Recommended)

```bash
# Run the test suite
aptos move test --profile quest_staking
```

### 4. Deploy the Contract

```bash
# Navigate back to project root
cd ../..

# Run the deployment script
node scripts/move/publish_quest.js
```

### 5. Verify Deployment

After successful deployment, you should see:
- ✅ Contract published successfully!
- 📦 Object Address: [Your contract address]
- 🔗 Transaction Hash: [Transaction hash]
- 📝 Updated frontend/.env with new module address

### 6. Update Frontend Environment

The script automatically updates `frontend/.env` with the new module address. If you need to do it manually:

```bash
# Add to frontend/.env
VITE_QUEST_MODULE_ADDRESS=0x[your_deployed_address]
```

## Manual Deployment (Alternative)

If you prefer to deploy manually:

```bash
# Navigate to quest-staking directory
cd quest-staking/move

# Deploy using Aptos CLI
aptos move publish --profile quest_staking
```

## Verification

1. **Check on Aptos Explorer**: Visit `https://explorer.aptoslabs.com/object/[your_address]?network=devnet`
2. **Test Frontend**: Navigate to `/quests` in your frontend to test the integration
3. **Create Test Quest**: Try creating a quest to verify everything works

## Troubleshooting

### Common Issues:

1. **Insufficient Funds**: Run `aptos account fund-with-faucet --profile quest_staking`
2. **Compilation Errors**: Check Move.toml address matches your account
3. **Permission Errors**: Ensure you're using the correct profile
4. **Network Issues**: Verify you're connected to devnet

### Reset Account (if needed):

```bash
# Generate new account
aptos init --profile quest_staking --network devnet

# Fund new account
aptos account fund-with-faucet --profile quest_staking
```

## Next Steps

After successful deployment:

1. ✅ Update your frontend environment variables
2. ✅ Test the quest management page
3. ✅ Create your first quest
4. ✅ Test the complete quest lifecycle

## Environment Variables

Make sure your `frontend/.env` contains:

```bash
VITE_APP_NETWORK=devnet
VITE_MODULE_ADDRESS=0x9239ac2bb7bb998c6d19d1b309dd2093f130185710415832caf30bf0c99d678a
VITE_QUEST_MODULE_ADDRESS=0x22d710758f35e3de12a5457419c356d97b36d766cf802a5d15b092cb231d4e1d
```

https://explorer.aptoslabs.com/txn/0x0536ae972b6d8107cf301c940e63382360611f7266777dbf245929555a1b0172?network=devnet