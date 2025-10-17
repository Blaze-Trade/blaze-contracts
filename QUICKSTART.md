# 🚀 Quick Start - Deploy to Testnet

Deploy Blaze Launchpad V2 to Aptos testnet in 3 steps!

---

## Prerequisites

```bash
# Install Aptos CLI (if not already installed)
curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3

# Verify installation
aptos --version
```

---

## 🎯 Deploy in 3 Steps

### Step 1: Run Deployment Script

```bash
cd /Users/jovian/Developer/aptos/blaze-contracts
./scripts/deploy-testnet.sh
```

**What it does:**
- ✅ Creates testnet profile
- ✅ Funds account from faucet
- ✅ Compiles contract
- ✅ Runs all 28 tests
- ✅ Deploys to testnet

**Expected Output:**
```
✅ Deployment complete!

📋 Contract Details:
   Network: Testnet
   Account: 0x9239ac2bb7bb998c6d19d1b309dd2093f130185710415832caf30bf0c99d678a
   Module: 0x9239...::launchpad_v2

🔗 View on Explorer:
   https://explorer.aptoslabs.com/account/0x9239.../network=testnet
```

**⚠️ IMPORTANT:** Save your contract address!

---

### Step 2: Test the Contract

```bash
./scripts/test-contract.sh
```

**Interactive Menu:**
```
1. Get Admin Address
2. Get Treasury Address
3. Get Oracle Data
4. Get APT/USD Price
5. Get All Pools
6. Get Pool Balance
7. Get Fees
8. Create a Test Pool
9. Update Oracle Price (Admin)
10. View Account Resources
11. Exit
```

**Try these first:**
```bash
# Check initial oracle price
Choose: 4

# View admin address
Choose: 1

# Create a test pool
Choose: 8
```

---

### Step 3: Create Your First Pool

After deployment, create a test pool:

**Option A: Using Script**
```bash
./scripts/test-contract.sh
# Choose option 8
```

**Option B: Manual CLI**
```bash
# Replace <CONTRACT_ADDRESS> with your deployed address
aptos move run \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::create_pool \
    --args \
        string:"Test Token" \
        string:"TEST" \
        string:"https://example.com/test.png" \
        "vector<string>:Test token description" \
        "vector<string>:https://test.com" \
        "vector<string>:@test" \
        "vector<string>:t.me/test" \
        "vector<string>:discord.gg/test" \
        "vector<u128>:1000000000000" \
        u8:8 \
        u64:50 \
        u64:100000000 \
        "vector<u64>:7500000"
```

---

## 📊 View Your Contract

### Aptos Explorer
```
https://explorer.aptoslabs.com/account/<YOUR_ADDRESS>?network=testnet
```

### Get Pool IDs
```bash
aptos move view \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::get_pools
```

### Check Market Cap
```bash
aptos move view \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::calculate_market_cap_usd \
    --args address:<POOL_ID>
```

---

## 🔧 Common Commands

### Fund Account
```bash
aptos account fund-with-faucet \
    --profile testnet \
    --account <YOUR_ADDRESS> \
    --amount 500000000
```

### Update Oracle Price (Admin Only)
```bash
aptos move run \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::update_oracle_price \
    --args u64:1200 address:<YOUR_ADDRESS>
```
*Sets APT price to $12.00*

### Buy Tokens
```bash
aptos move run \
    --profile testnet \
    --function-id <CONTRACT_ADDRESS>::launchpad_v2::buy \
    --args \
        address:<POOL_ID> \
        u64:10000000 \
        u64:0 \
        u64:$(($(date +%s) + 300))
```
*Buys 0.1 APT worth of tokens*

---

## 📝 Important Notes

### Save These Details:
- ✅ Contract address
- ✅ Private key (stored in `~/.aptos/config.yaml`)
- ✅ Pool IDs after creation

### Testnet Limitations:
- ⚠️ Testnet tokens have no value
- ⚠️ Faucet may rate-limit (wait if needed)
- ⚠️ Data may be reset periodically

### Admin Functions:
Only the deployer account can:
- Update oracle price
- Force migration
- Update fees
- Change admin/treasury

---

## 🎓 Next Steps

1. **Full Guide:** See `DEPLOYMENT_GUIDE.md` for detailed documentation
2. **SDK Integration:** Check `examples/frontend-integration.ts` for TypeScript SDK usage
3. **Test Everything:** Run through all menu options in test script
4. **Monitor:** Watch your contract on Aptos Explorer
5. **Frontend:** Integrate with your web app using the SDK examples

---

## 🆘 Troubleshooting

### Script fails with "permission denied"
```bash
chmod +x scripts/*.sh
```

### "Insufficient balance" error
```bash
# Fund your account
aptos account fund-with-faucet --profile testnet --account <ADDRESS> --amount 500000000
```

### Can't find contract address
```bash
aptos config show-profiles --profile testnet
```

### Need to reset/redeploy
Create a new testnet profile:
```bash
aptos init --profile testnet2 --network testnet
# Then use --profile testnet2 for all commands
```

---

## 📚 Documentation

- **Full Deployment Guide:** `DEPLOYMENT_GUIDE.md`
- **Implementation Status:** `Docs/V2-IMPLEMENTATION-STATUS.md`
- **Contract Spec:** `Docs/LAUNCHPAD_V2_CONTRACT_SPEC.md`
- **PRD:** `Docs/PRD-launchpad-v2.md`

---

## ✅ Checklist

- [ ] Install Aptos CLI
- [ ] Run deployment script
- [ ] Save contract address
- [ ] Test view functions
- [ ] Create test pool
- [ ] Update oracle price
- [ ] Buy tokens
- [ ] Check market cap
- [ ] Verify on explorer

---

**Ready to deploy? Run:**
```bash
./scripts/deploy-testnet.sh
```

**Need help?** Check `DEPLOYMENT_GUIDE.md` for detailed instructions!
