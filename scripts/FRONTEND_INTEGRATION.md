# Blaze Launchpad V2 - Frontend Integration Guide

This guide explains how to integrate Blaze Launchpad V2 into your frontend application.

## 📦 Installation

```bash
npm install @aptos-labs/ts-sdk
```

**Note:** Copy `blaze-sdk.ts` to your project. Import paths depend on your build setup:
- **With bundler (Vite, Webpack, etc.):** Use `from './blaze-sdk'`
- **Direct ES modules:** Use `from './blaze-sdk.js'` 
- **TypeScript project:** The imports shown below will work after compilation

## 🚀 Quick Start

### 1. Import the SDK

```typescript
import {
  createPool,
  buyTokens,
  sellTokens,
  getPools,
  getPoolBalance,
  CONTRACT_ADDRESS
} from './blaze-sdk';
```

### 2. Connect Wallet

```typescript
import { Account } from "@aptos-labs/ts-sdk";

// For wallet integration, use Petra, Martian, or other Aptos wallets
// This example uses direct account creation (for testing only)
const account = Account.fromPrivateKey({ privateKey });
```

### 3. Create a Pool

```typescript
const result = await createPool(account, {
  name: "My Token",
  ticker: "MTK",
  imageUri: "https://example.com/logo.png",
  description: "My amazing token",
  website: "https://mytoken.com",
  twitter: "@mytoken",
  decimals: 8,
  reserveRatio: 50,
  initialReserveApt: 0.1,
  thresholdUsd: 75000
});

console.log(`Pool created! Hash: ${result.hash}`);
console.log(`View on explorer: ${result.explorerUrl}`);
```

### 4. Buy Tokens

```typescript
const poolId = "0x1234..."; // Get from getPools() or pool creation

const result = await buyTokens(
  account,
  poolId,
  0.1,  // Buy with 0.1 APT
  0,    // Min tokens out (slippage protection)
  5     // 5 minute deadline
);

console.log(`Tokens purchased! Hash: ${result.hash}`);
```

### 5. Sell Tokens

```typescript
const result = await sellTokens(
  account,
  poolId,
  100,  // Sell 100 tokens
  0,    // Min APT out (slippage protection)
  8,    // Token decimals
  5     // 5 minute deadline
);

console.log(`Tokens sold! Hash: ${result.hash}`);
```

## 📚 API Reference

### Main Functions

#### `createPool(account, params, network?)`

Creates a new token pool with bonding curve.

**Parameters:**
- `account: Account` - Signer account
- `params: CreatePoolParams` - Pool configuration
  - `name: string` - Token name (required)
  - `ticker: string` - Token ticker, 1-10 chars (required)
  - `imageUri: string` - Token image URL (required)
  - `description?: string` - Token description (optional)
  - `website?: string` - Website URL (optional)
  - `twitter?: string` - Twitter handle (optional)
  - `telegram?: string` - Telegram link (optional)
  - `discord?: string` - Discord link (optional)
  - `maxSupply?: bigint` - Max supply (optional, undefined = unlimited)
  - `decimals?: number` - Decimals (default: 8)
  - `reserveRatio?: number` - Reserve ratio 1-100% (default: 50)
  - `initialReserveApt: number` - Initial APT reserve (required)
  - `thresholdUsd?: number` - Market cap threshold in USD (optional)
- `network?: Network` - Network to use (default: TESTNET)

**Returns:** `Promise<TransactionResult>`

---

#### `buyTokens(account, poolId, aptAmount, minTokensOut?, deadlineMinutes?, network?)`

Buy tokens from a pool using APT.

**Parameters:**
- `account: Account` - Signer account
- `poolId: string` - Pool object address
- `aptAmount: number` - Amount of APT to spend
- `minTokensOut?: number` - Minimum tokens to receive (default: 0)
- `deadlineMinutes?: number` - Deadline in minutes (default: 5)
- `network?: Network` - Network to use (default: TESTNET)

**Returns:** `Promise<TransactionResult>`

---

#### `sellTokens(account, poolId, tokenAmount, minAptOut?, decimals?, deadlineMinutes?, network?)`

Sell tokens to a pool for APT.

**Parameters:**
- `account: Account` - Signer account
- `poolId: string` - Pool object address
- `tokenAmount: number` - Amount of tokens to sell
- `minAptOut?: number` - Minimum APT to receive (default: 0)
- `decimals?: number` - Token decimals (default: 8)
- `deadlineMinutes?: number` - Deadline in minutes (default: 5)
- `network?: Network` - Network to use (default: TESTNET)

**Returns:** `Promise<TransactionResult>`

---

### View Functions

#### `getPools(network?)`

Get all pool IDs.

**Returns:** `Promise<string[]>` - Array of pool addresses

---

#### `getPoolBalance(poolId, network?)`

Get pool's APT reserve balance.

**Parameters:**
- `poolId: string` - Pool object address

**Returns:** `Promise<number>` - Balance in octas (1 APT = 100,000,000 octas)

---

### Helper Functions

#### `aptToOctas(apt: number): number`

Convert APT to octas (1 APT = 100,000,000 octas).

---

#### `octasToApt(octas: number): number`

Convert octas to APT.

---

#### `tokensToBaseUnits(tokens: number, decimals: number): number`

Convert tokens to base units with decimals.

---

#### `baseUnitsToTokens(baseUnits: number, decimals: number): number`

Convert base units to tokens.

---

#### `getExplorerUrl(txHash: string, network?: Network): string`

Get explorer URL for a transaction.

---

## 🎨 React Example

```typescript
import { useState } from 'react';
import { useWallet } from '@aptos-labs/wallet-adapter-react';
import { buyTokens, octasToApt } from './blaze-sdk';

function BuyTokensButton({ poolId }: { poolId: string }) {
  const { account, signAndSubmitTransaction } = useWallet();
  const [loading, setLoading] = useState(false);
  const [amount, setAmount] = useState('0.1');

  const handleBuy = async () => {
    if (!account) {
      alert('Please connect your wallet');
      return;
    }

    setLoading(true);
    try {
      const result = await buyTokens(
        account,
        poolId,
        parseFloat(amount)
      );
      
      alert(`Success! Tx: ${result.hash}`);
      window.open(result.explorerUrl, '_blank');
    } catch (error: any) {
      alert(`Error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <input
        type="number"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
        placeholder="APT amount"
        step="0.01"
        min="0.01"
      />
      <button onClick={handleBuy} disabled={loading}>
        {loading ? 'Buying...' : 'Buy Tokens'}
      </button>
    </div>
  );
}
```

## 🔐 Security Best Practices

1. **Never expose private keys** - Use wallet adapters (Petra, Martian, etc.)
2. **Validate inputs** - Check amounts, addresses, and parameters
3. **Use slippage protection** - Set `minTokensOut` and `minAptOut` appropriately
4. **Set reasonable deadlines** - Default 5 minutes is usually sufficient
5. **Handle errors gracefully** - Show user-friendly error messages
6. **Test on testnet first** - Always test before mainnet deployment

## 🌐 Networks

```typescript
import { Network } from "@aptos-labs/ts-sdk";

// Use testnet (default)
await createPool(account, params, Network.TESTNET);

// Use mainnet
await createPool(account, params, Network.MAINNET);
```

## 🛠️ Common Patterns

### Get Pool Info and Buy

```typescript
// 1. Get all pools
const pools = await getPools();

// 2. Get balance for first pool
const poolId = pools[0];
const balanceOctas = await getPoolBalance(poolId);
const balanceApt = octasToApt(balanceOctas);

console.log(`Pool has ${balanceApt} APT`);

// 3. Buy tokens
const result = await buyTokens(account, poolId, 0.1);
```

### Create Pool with Minimal Config

```typescript
const result = await createPool(account, {
  name: "Simple Token",
  ticker: "SMPL",
  imageUri: "https://example.com/logo.png",
  decimals: 8,
  reserveRatio: 50,
  initialReserveApt: 0.05
  // All other fields are optional
});
```

### Error Handling

```typescript
try {
  const result = await buyTokens(account, poolId, 0.1);
  console.log('Success:', result.hash);
} catch (error: any) {
  if (error.message.includes('INSUFFICIENT_BALANCE')) {
    console.error('Not enough APT balance');
  } else if (error.message.includes('EDEADLINE_PASSED')) {
    console.error('Transaction deadline passed');
  } else {
    console.error('Unknown error:', error.message);
  }
}
```

## 📱 Wallet Integration

For production apps, integrate with Aptos wallets:

```typescript
import { useWallet } from '@aptos-labs/wallet-adapter-react';

function MyComponent() {
  const { account, connected, connect } = useWallet();

  const handleCreatePool = async () => {
    if (!connected) {
      await connect('Petra'); // or 'Martian', etc.
    }

    const result = await createPool(account, {
      // ... pool params
    });
  };
}
```

## 🔗 Resources

- **Contract Address (Testnet):** `0xf2ca7e5f4e8fb07ea86f701ca1fd1da98d5c41d2f87979be0723a13da3bca125`
- **Aptos SDK Docs:** https://aptos.dev/sdks/ts-sdk/
- **Explorer:** https://explorer.aptoslabs.com/?network=testnet
- **Wallet Adapters:** https://github.com/aptos-labs/aptos-wallet-adapter

## 💡 Tips

1. **Token amounts** are in human-readable units (e.g., 100 tokens), not base units
2. **APT amounts** are in APT (e.g., 0.1 APT), not octas
3. **Deadlines** are in minutes from now (e.g., 5 for 5 minutes)
4. **Pool IDs** are object addresses, get them from `getPools()`
5. **Use helper functions** like `octasToApt()` for conversions

## ❓ Support

For questions or issues:
1. Check the example file: `sdk-example.ts`
2. Review the SDK source: `blaze-sdk.ts`
3. Contact the Blaze team

---

**Happy building! 🚀**
