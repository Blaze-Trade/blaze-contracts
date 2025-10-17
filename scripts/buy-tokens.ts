#!/usr/bin/env ts-node

/**
 * Buy Tokens Script
 * 
 * Usage: 
 *   POOL_ID=0x... APT_AMOUNT=0.1 npm run buy
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
  console.log("💰 Buy Tokens\n");

  const contractAddress = process.env.CONTRACT_ADDRESS || "0xf2ca7e5f4e8fb07ea86f701ca1fd1da98d5c41d2f87979be0723a13da3bca125";
  const poolId = process.env.POOL_ID;
  const aptAmount = process.env.APT_AMOUNT || "0.01"; // Default 0.01 APT
  const minTokensOut = process.env.MIN_TOKENS_OUT || "0"; // No slippage protection by default
  
  if (!poolId) {
    console.log("❌ Error: POOL_ID environment variable is required");
    console.log("\nUsage:");
    console.log("  POOL_ID=0x... APT_AMOUNT=0.1 npm run buy");
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
  console.log(`💵 Buying with: ${aptAmount} APT\n`);

  const aptAmountOctas = Math.floor(parseFloat(aptAmount) * 100000000);
  const deadline = Math.floor(Date.now() / 1000) + 300; // 5 minutes from now

  try {
    const transaction = await aptos.transaction.build.simple({
      sender: account.accountAddress,
      data: {
        function: `${contractAddress}::launchpad_v2::buy`,
        functionArguments: [
          poolId,                        // pool_id: Object<Metadata>
          aptAmountOctas,               // apt_amount: u64
          parseInt(minTokensOut),       // min_tokens_out: u64
          deadline                      // deadline: u64
        ],
      },
    });

    console.log("🔨 Submitting buy transaction...\n");

    const committedTxn = await aptos.signAndSubmitTransaction({
      signer: account,
      transaction,
    });

    console.log("⏳ Waiting for confirmation...\n");
    
    const result = await aptos.waitForTransaction({ 
      transactionHash: committedTxn.hash 
    });

    console.log("✅ Tokens purchased successfully!\n");
    console.log(`📝 Transaction: ${committedTxn.hash}`);
    console.log(`🔗 Explorer: https://explorer.aptoslabs.com/txn/${committedTxn.hash}?network=testnet\n`);

  } catch (error: any) {
    console.error("❌ Error buying tokens:", error.message || error);
    process.exit(1);
  }
}

main().catch(console.error);
