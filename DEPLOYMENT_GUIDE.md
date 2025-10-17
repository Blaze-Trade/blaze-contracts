# Blaze Launchpad V2 - Testnet Deployment Guide

Complete guide for deploying and testing the Launchpad V2 contract on Aptos testnet.

---

## Prerequisites

### 1. Install Aptos CLI

```bash
# macOS/Linux
curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3

# Verify installation
aptos --version
```

### 2. Set Up Directory

```bash
cd /Users/jovian/Developer/aptos/blaze-contracts
```

---

## Quick Deployment (Automated)

### Step 1: Make Script Executable

```bash
chmod +x scripts/deploy-testnet.sh
chmod +x scripts/test-contract.sh
```

### Step 2: Deploy Contract

```bash
./scripts/deploy-testnet.sh
```

This script will:
1. ✅ Check for Aptos CLI
2. ✅ Create/use testnet profile
3. ✅ Fund account from faucet
4. ✅ Compile contract
5. ✅ Run tests
6. ✅ Deploy to testnet

**Expected Output:**
```
✅ Deployment complete!

📋 Contract Details:
   Network: Testnet
   Account: 0x123...abc
   Module: 0x123...abc::launchpad_v2

🔗 View on Explorer:
   https://explorer.aptoslabs.com/account/0x123...abc?network=testnet
```

---

## Manual Deployment Steps

### Step 1: Initialize Testnet Profile

```bash
aptos init --profile testnet --network testnet
```

- Choose to create a new account or use an existing private key
- Save your private key securely!

### Step 2: Fund Your Account

```bash
# Get your account address
aptos config show-profiles --profile testnet

# Fund from faucet (500 APT)
aptos account fund-with-faucet --profile testnet --account <YOUR_ADDRESS> --amount 500000000
```

### Step 3: Update Move.toml

The contract address is automatically set during compilation, but verify:

```toml
[addresses]
blaze_token_launchpad = "_"
```
e.g
```toml
[addresses]
blaze_token_launchpad = "0xf2ca7e5f4e8fb07ea86f701ca1fd1da98d5c41d2f87979be0723a13da3bca125"
```

### Step 4: Compile Contract

```bash
cd move
aptos move compile --named-addresses blaze_token_launchpad=<YOUR_ADDRESS>
```

### Step 5: Run Tests

```bash
aptos move test --filter launchpad_v2
```

Expected: `Test result: OK. Total tests: 28; passed: 28; failed: 0`

### Step 6: Deploy to Testnet

```bash
aptos move publish \
    --profile testnet \
    --named-addresses blaze_token_launchpad=<YOUR_ADDRESS> \
    --assume-yes
```

e.g
```bash
aptos move publish \
    --profile blazev2-testnet \
    --named-addresses blaze_token_launchpad=0xf2ca7e5f4e8fb07ea86f701ca1fd1da98d5c41d2f87979be0723a13da3bca125 \
    --assume-yes
```

---

## Testing the Deployed Contract

### Interactive Testing Script

```bash
./scripts/test-contract.sh
```

Choose from menu options:
1. **Get Admin Address** - View current admin
2. **Get Treasury Address** - View treasury address
3. **Get Oracle Data** - Check APT/USD price oracle
4. **Get APT/USD Price** - Current price in cents
5. **Get All Pools** - List all created pools
6. **Get Fees** - View buy/sell fees
7. **Create a Test Pool** - Create a new token pool
8. **Update Oracle Price** - Admin function to update price
9. **View Account Resources** - See all contract resources
10. **Exit**

### Manual View Function Calls

```bash
# Get admin address
aptos move view \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::get_admin

# Get oracle data
aptos move view \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::get_oracle_data

# Get all pools
aptos move view \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::get_pools
```

---

## Creating Your First Pool

### Using CLI

```bash
aptos move run \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::create_pool \
    --args \
        string:"My Token" \
        string:"MTK" \
        string:"https://example.com/token.png" \
        "vector<string>:A great token for testing" \
        "vector<string>:https://mytoken.com" \
        "vector<string>:@mytoken" \
        "vector<string>:t.me/mytoken" \
        "vector<string>:discord.gg/mytoken" \
        "vector<u128>:1000000000000" \
        u8:8 \
        u64:50 \
        u64:100000000 \
        "vector<u64>:7500000"
```

**Parameter Explanation:**
- `My Token` - Token name
- `MTK` - Token ticker (1-10 chars)
- `https://...` - Token image URI
- `A great token...` - Description (optional, use empty vector for none)
- Social links (optional, use empty vectors for none)
- `1000000000000` - Max supply (10,000 tokens with 8 decimals)
- `8` - Decimals
- `50` - Reserve ratio (50%)
- `100000000` - Initial APT reserve (1 APT = 100000000 octas)
- `7500000` - Market cap threshold ($75,000)

### Using TypeScript SDK

```typescript
import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";

const config = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(config);

const contractAddress = "YOUR_CONTRACT_ADDRESS";

// Create pool transaction
const transaction = await aptos.transaction.build.simple({
  sender: account.accountAddress,
  data: {
    function: `${contractAddress}::launchpad_v2::create_pool`,
    typeArguments: [],
    functionArguments: [
      "My Token",                        // name
      "MTK",                              // ticker
      "https://example.com/token.png",   // image
      ["Description here"],               // description (optional)
      ["https://mytoken.com"],           // website (optional)
      ["@mytoken"],                       // twitter (optional)
      ["t.me/mytoken"],                   // telegram (optional)
      ["discord.gg/mytoken"],            // discord (optional)
      [1000000000000],                    // max_supply (optional)
      8,                                  // decimals
      50,                                 // reserve_ratio
      100000000,                          // initial_apt_reserve (1 APT)
      [7500000]                          // market_cap_threshold (optional)
    ],
  },
});

const committedTxn = await aptos.signAndSubmitTransaction({
  signer: account,
  transaction,
});

await aptos.waitForTransaction({ transactionHash: committedTxn.hash });
```

---

## Buying Tokens

```bash
aptos move run \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::buy \
    --args \
        address:<POOL_OBJECT_ADDRESS> \
        u64:10000000 \
        u64:0 \
        u64:$(date +%s + 300)
```

**Parameters:**
- Pool object address (get from `get_pools()`)
- APT amount (0.1 APT = 10000000)
- Min tokens out (slippage protection, use 0 for testing)
- Deadline (current timestamp + 300 seconds)

---

## Updating Oracle Price (Admin Only)

```bash
aptos move run \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::update_oracle_price \
    --args \
        u64:1200 \
        address:<ORACLE_ADDRESS>
```

**Parameters:**
- Price in cents (1200 = $12.00)
- Oracle address (can be your admin address for testing)

---

## Monitoring Your Contract

### 1. Aptos Explorer

View your contract on the official explorer:
```
https://explorer.aptoslabs.com/account/<YOUR_ADDRESS>?network=testnet
```

### 2. View All Resources

```bash
aptos account list --profile testnet --account <YOUR_ADDRESS>
```

### 3. View Specific Resource

```bash
aptos account list --profile testnet --account <YOUR_ADDRESS> --query resources
```

### 4. View Events

Events are automatically emitted for:
- `CreatePoolEvent` - Pool creation
- `BuyEvent` - Token purchases
- `SellEvent` - Token sales
- `OraclePriceUpdatedEvent` - Oracle updates
- `LiquidityMigratedEvent` - DEX migration

---

## Common Issues & Solutions

### Issue: "Insufficient balance"
**Solution:** Fund your account from faucet:
```bash
aptos account fund-with-faucet --profile testnet --account <ADDRESS> --amount 500000000
```

### Issue: "Module already exists"
**Solution:** You're trying to redeploy. Either:
1. Use `--override` flag (NOT recommended for production)
2. Create a new account for testing

### Issue: "Transaction failed - EONLY_ADMIN"
**Solution:** Ensure you're using the admin account (the one that deployed the contract)

### Issue: "Pool not found"
**Solution:** Get the correct pool object address using:
```bash
aptos move view --function-id <CONTRACT>::launchpad_v2::get_pools
```

---

## Next Steps

1. ✅ **Deploy contract** - Use automated script
2. ✅ **Update oracle price** - Set initial APT/USD price
3. ✅ **Create test pool** - Create your first token
4. ✅ **Buy tokens** - Test the bonding curve
5. ✅ **Monitor market cap** - Watch for migration threshold
6. ✅ **Integrate frontend** - Use TypeScript SDK

---

## Frontend Integration Example

See `examples/frontend-integration.ts` for complete SDK usage examples.

Key functions to integrate:
- `create_pool()` - Create new tokens
- `buy()` - Purchase tokens
- `sell()` - Sell tokens
- `calculate_market_cap_usd()` - Display market cap
- `is_migration_threshold_reached()` - Check migration status
- `get_current_price()` - Get token price

---

## Security Checklist

Before mainnet deployment:

- [ ] Test all functions thoroughly on testnet
- [ ] Verify oracle price updates work correctly
- [ ] Test migration flow (if possible)
- [ ] Review admin permissions
- [ ] Set proper treasury address
- [ ] Configure appropriate fee structure
- [ ] Audit market cap calculations
- [ ] Test with multiple pools
- [ ] Verify slippage protection
- [ ] Test deadline enforcement

---

## Support & Resources

- **Aptos Documentation:** https://aptos.dev
- **Aptos Explorer (Testnet):** https://explorer.aptoslabs.com/?network=testnet
- **Aptos Discord:** https://discord.gg/aptoslabs
- **Contract Source:** `/move/sources/launchpad_v2.move`
- **Implementation Status:** `/Docs/V2-IMPLEMENTATION-STATUS.md`

---

## Contact

For issues or questions about this deployment:
- Review implementation docs in `/Docs/`
- Check test coverage in contract tests
- Refer to PRD: `/Docs/PRD-launchpad-v2.md`

**Happy deploying! 🚀**
