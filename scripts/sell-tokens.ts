#!/usr/bin/env ts-node

/**
 * Sell Tokens Script
 * 
 * Usage: 
 *   POOL_ID=0x... TOKEN_AMOUNT=100 npm run sell
 */

import { 
  Aptos, 
  AptosConfig, 
  Network, 
  Account,
  Ed25519PrivateKey
} from "@aptos-labs/ts-sdk";
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import YAML from 'yaml';

function findConfigPath(): string | null {
  const projectConfig = path.join(process.cwd(), '.aptos', 'config.yaml');
  if (fs.existsSync(projectConfig)) return projectConfig;
  
  const parentConfig = path.join(process.cwd(), '..', '.aptos', 'config.yaml');
  if (fs.existsSync(parentConfig)) return parentConfig;
  
  const homeConfig = path.join(os.homedir(), '.aptos', 'config.yaml');
  if (fs.existsSync(homeConfig)) return homeConfig;
  
  return null;
}

function readAptosConfig(): { privateKey?: string, profileUsed?: string } {
  try {
    const configPath = findConfigPath();
    if (!configPath) return {};
    
    const configContent = fs.readFileSync(configPath, 'utf8');
    const config = YAML.parse(configContent);
    
    if (!config.profiles) return {};
    
    const commonProfiles = ['blazev2-testnet', 'testnet', 'default'];
    for (const profile of commonProfiles) {
      if (config.profiles[profile]) {
        return {
          privateKey: config.profiles[profile].private_key,
          profileUsed: profile
        };
      }
    }
    
    const firstProfile = Object.keys(config.profiles)[0];
    if (firstProfile) {
      return {
        privateKey: config.profiles[firstProfile].private_key,
        profileUsed: firstProfile
      };
    }
    
    return {};
  } catch (error) {
    return {};
  }
}

async function main() {
  console.log("💸 Sell Tokens\n");

  const contractAddress = process.env.CONTRACT_ADDRESS || "0xf2ca7e5f4e8fb07ea86f701ca1fd1da98d5c41d2f87979be0723a13da3bca125";
  const poolId = process.env.POOL_ID;
  const tokenAmount = process.env.TOKEN_AMOUNT || "100"; // Default 100 tokens
  const minAptOut = process.env.MIN_APT_OUT || "0"; // No slippage protection by default
  
  if (!poolId) {
    console.log("❌ Error: POOL_ID environment variable is required");
    console.log("\nUsage:");
    console.log("  POOL_ID=0x... TOKEN_AMOUNT=100 npm run sell");
    console.log("\nTo get pool IDs:");
    console.log(`  aptos move view --function-id ${contractAddress}::launchpad_v2::get_pools --profile testnet\n`);
    process.exit(1);
  }

  const config = new AptosConfig({ network: Network.TESTNET });
  const aptos = new Aptos(config);

  const aptosConfig = readAptosConfig();
  if (!aptosConfig.privateKey) {
    console.log("❌ Error: No config file found");
    process.exit(1);
  }

  const privateKey = new Ed25519PrivateKey(aptosConfig.privateKey);
  const account = Account.fromPrivateKey({ privateKey });

  console.log(`📍 Contract: ${contractAddress}`);
  console.log(`🏊 Pool ID: ${poolId}`);
  console.log(`👤 Account: ${account.accountAddress}`);
  console.log(`🪙 Selling: ${tokenAmount} tokens\n`);

  // Token amounts are in base units (with decimals)
  // For 8 decimals: 100 tokens = 10000000000
  const tokenAmountBase = Math.floor(parseFloat(tokenAmount) * 100000000);
  const minAptOutOctas = Math.floor(parseFloat(minAptOut) * 100000000);
  const deadline = Math.floor(Date.now() / 1000) + 300; // 5 minutes from now

  try {
    const transaction = await aptos.transaction.build.simple({
      sender: account.accountAddress,
      data: {
        function: `${contractAddress}::launchpad_v2::sell`,
        functionArguments: [
          poolId,                        // pool_id: Object<Metadata>
          tokenAmountBase,              // token_amount: u64
          minAptOutOctas,               // min_apt_out: u64
          deadline                      // deadline: u64
        ],
      },
    });

    console.log("🔨 Submitting sell transaction...\n");

    const committedTxn = await aptos.signAndSubmitTransaction({
      signer: account,
      transaction,
    });

    console.log("⏳ Waiting for confirmation...\n");
    
    const result = await aptos.waitForTransaction({ 
      transactionHash: committedTxn.hash 
    });

    console.log("✅ Tokens sold successfully!\n");
    console.log(`📝 Transaction: ${committedTxn.hash}`);
    console.log(`🔗 Explorer: https://explorer.aptoslabs.com/txn/${committedTxn.hash}?network=testnet\n`);

  } catch (error: any) {
    console.error("❌ Error selling tokens:", error.message || error);
    process.exit(1);
  }
}

main().catch(console.error);
