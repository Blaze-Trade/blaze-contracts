# Scripts Usage Guide

## Using Custom Profile Names

Both scripts now support custom Aptos CLI profiles!

### Deployment Script

**Option 1: Use default profile (testnet)**
```bash
./scripts/deploy-testnet.sh
```

**Option 2: Use custom profile (e.g., blazev2-testnet)**
```bash
APTOS_PROFILE=blazev2-testnet ./scripts/deploy-testnet.sh
```

### Testing Script

The test script now supports custom profiles in three ways!

**Option 1: Use default profile (testnet)**
```bash
./scripts/test-contract.sh
```

**Option 2: Pass profile as argument**
```bash
./scripts/test-contract.sh blazev2-testnet
```

**Option 3: Use environment variable**
```bash
APTOS_PROFILE=blazev2-testnet ./scripts/test-contract.sh
```

**Priority:** Command argument > Environment variable > Default (testnet)

## Setting Up a New Profile

```bash
# Create new profile
aptos init --profile blazev2-testnet --network testnet

# Fund the account
aptos account fund-with-faucet --profile blazev2-testnet --account <YOUR_ADDRESS> --amount 500000000

# Deploy with custom profile
APTOS_PROFILE=blazev2-testnet ./scripts/deploy-testnet.sh
```

## Quick Reference

### Deploy
```bash
# With default profile
./scripts/deploy-testnet.sh

# With custom profile
APTOS_PROFILE=blazev2-testnet ./scripts/deploy-testnet.sh
```

### Test
```bash
# With default profile
./scripts/test-contract.sh

# With custom profile (any of these work):
./scripts/test-contract.sh blazev2-testnet
APTOS_PROFILE=blazev2-testnet ./scripts/test-contract.sh
```

### View Profile Info
```bash
aptos config show-profiles --profile blazev2-testnet
```

### Get Account Address
```bash
aptos config show-profiles --profile blazev2-testnet | grep "account" | awk '{print $2}' | tr -d '","'
```

## Troubleshooting

### Issue: Account address has quotes/comma
**Fixed!** Scripts now automatically clean the address format.

### Issue: Missing 0x prefix
**Fixed!** Scripts now automatically add the `0x` prefix if missing.

### Issue: Profile not found
Make sure your profile exists:
```bash
aptos config show-profiles
```

Create if missing:
```bash
aptos init --profile YOUR_PROFILE_NAME --network testnet
```
