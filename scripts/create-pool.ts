#!/usr/bin/env ts-node

/**
 * Create Pool Script - Works around Aptos CLI limitations with Option<T>
 * 
 * Usage: ts-node scripts/create-pool.ts
 */

import { 
  Aptos, 
  AptosConfig, 
  Network, 
  Account,
  Ed25519PrivateKey
} from "@aptos-labs/ts-sdk";
import * as readline from 'readline';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import YAML from 'yaml';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(prompt: string): Promise<string> {
  return new Promise((resolve) => {
    rl.question(prompt, resolve);
  });
}

function findConfigPath(): string | null {
  // Try project directory first
  const projectConfig = path.join(process.cwd(), '.aptos', 'config.yaml');
  if (fs.existsSync(projectConfig)) {
    return projectConfig;
  }
  
  // Try parent directory (if running from scripts folder)
  const parentConfig = path.join(process.cwd(), '..', '.aptos', 'config.yaml');
  if (fs.existsSync(parentConfig)) {
    return parentConfig;
  }
  
  // Fall back to home directory
  const homeConfig = path.join(os.homedir(), '.aptos', 'config.yaml');
  if (fs.existsSync(homeConfig)) {
    return homeConfig;
  }
  
  return null;
}

function listAptosProfiles(): string[] {
  try {
    const configPath = findConfigPath();
    if (!configPath) {
      return [];
    }
    
    const configContent = fs.readFileSync(configPath, 'utf8');
    const config = YAML.parse(configContent);
    
    if (config.profiles) {
      return Object.keys(config.profiles);
    }
    
    return [];
  } catch (error) {
    return [];
  }
}

function readAptosConfig(profileName?: string): { privateKey?: string, account?: string, profileUsed?: string, configPath?: string } {
  try {
    const configPath = findConfigPath();
    if (!configPath) {
      return {};
    }
    
    const configContent = fs.readFileSync(configPath, 'utf8');
    const config = YAML.parse(configContent);
    
    if (!config.profiles) {
      return {};
    }
    
    // Try specified profile first
    if (profileName && config.profiles[profileName]) {
      return {
        privateKey: config.profiles[profileName].private_key,
        account: config.profiles[profileName].account,
        profileUsed: profileName,
        configPath
      };
    }
    
    // Try common profile names in order
    const commonProfiles = ['blazev2-testnet', 'testnet', 'default'];
    for (const profile of commonProfiles) {
      if (config.profiles[profile]) {
        return {
          privateKey: config.profiles[profile].private_key,
          account: config.profiles[profile].account,
          profileUsed: profile,
          configPath
        };
      }
    }
    
    // If no common profiles found, use the first available one
    const firstProfile = Object.keys(config.profiles)[0];
    if (firstProfile) {
      return {
        privateKey: config.profiles[firstProfile].private_key,
        account: config.profiles[firstProfile].account,
        profileUsed: firstProfile,
        configPath
      };
    }
    
    return {};
  } catch (error) {
    console.error('⚠️  Error reading config.yaml:', error);
    return {};
  }
}

async function main() {
  console.log("🚀 Blaze Launchpad V2 - Create Pool\n");

  // Get contract address from environment or prompt
  const contractAddress = process.env.CONTRACT_ADDRESS || "0xf2ca7e5f4e8fb07ea86f701ca1fd1da98d5c41d2f87979be0723a13da3bca125";
  console.log(`📍 Contract: ${contractAddress}\n`);

  // Initialize Aptos client
  const config = new AptosConfig({ network: Network.TESTNET });
  const aptos = new Aptos(config);

  // Show available profiles
  const profiles = listAptosProfiles();
  if (profiles.length > 0) {
    console.log(`📋 Available profiles: ${profiles.join(', ')}\n`);
  }

  // Check if we should use config automatically (PRIVATE_KEY env var or auto mode)
  const privateKeyEnv = process.env.PRIVATE_KEY;
  const autoMode = process.env.AUTO_MODE === 'true' || !process.stdin.isTTY;
  
  let account: Account;
  
  if (privateKeyEnv) {
    // Use environment variable
    console.log("🔑 Using private key from PRIVATE_KEY environment variable\n");
    const privateKey = new Ed25519PrivateKey(privateKeyEnv);
    account = Account.fromPrivateKey({ privateKey });
  } else if (autoMode) {
    // Auto mode - use config file directly
    console.log("🤖 Auto mode - using config file\n");
    const aptosConfig = readAptosConfig();
    
    if (!aptosConfig.privateKey) {
      console.log("\n❌ Error: No config file found");
      console.log("   Searched in:");
      console.log("   - .aptos/config.yaml (project directory)");
      console.log("   - ../.aptos/config.yaml (parent directory)");
      console.log("   - ~/.aptos/config.yaml (home directory)");
      console.log("\n   Set PRIVATE_KEY environment variable or create config:\n");
      console.log("   aptos init --profile testnet --network testnet\n");
      rl.close();
      process.exit(1);
    }
    
    const privateKey = new Ed25519PrivateKey(aptosConfig.privateKey);
    account = Account.fromPrivateKey({ privateKey });
    console.log(`✅ Found config: ${aptosConfig.configPath}`);
    console.log(`✅ Loaded profile: ${aptosConfig.profileUsed}`);
  } else {
    // Interactive mode - ask user
    const privateKeyInput = await question("Enter your private key (or press Enter to use config): ");
    
    if (privateKeyInput.trim()) {
      const privateKey = new Ed25519PrivateKey(privateKeyInput.trim());
      account = Account.fromPrivateKey({ privateKey });
    } else {
      // Try to read from config file
      console.log("📖 Looking for config file...");
      const aptosConfig = readAptosConfig();
      
      if (!aptosConfig.privateKey) {
        console.log("\n❌ Error: No config file found");
        console.log("   Searched in:");
        console.log("   - .aptos/config.yaml (project directory)");
        console.log("   - ../.aptos/config.yaml (parent directory)");
        console.log("   - ~/.aptos/config.yaml (home directory)");
        console.log("\n   Run this to create one:");
        console.log("   aptos init --profile testnet --network testnet");
        console.log("\n   Or provide your private key directly when prompted\n");
        rl.close();
        return;
      }
      
      const privateKey = new Ed25519PrivateKey(aptosConfig.privateKey);
      account = Account.fromPrivateKey({ privateKey });
      console.log(`✅ Found config: ${aptosConfig.configPath}`);
      console.log(`✅ Loaded profile: ${aptosConfig.profileUsed}`);
    }
  }

  console.log(`\n👤 Using account: ${account.accountAddress}\n`);

  rl.close();

  // Use default test values (can be configured via environment variables)
  const name = process.env.TOKEN_NAME || "Test Token";
  const ticker = process.env.TOKEN_TICKER || "TEST";
  const imageUri = process.env.TOKEN_IMAGE || "https://example.com/test.png";
  const description = process.env.TOKEN_DESCRIPTION || "Test token for Blaze Launchpad";
  const website = process.env.TOKEN_WEBSITE || "";
  const twitter = process.env.TOKEN_TWITTER || "";
  const telegram = process.env.TOKEN_TELEGRAM || "";
  const discord = process.env.TOKEN_DISCORD || "";
  const maxSupplyStr = process.env.TOKEN_MAX_SUPPLY || "";
  const decimals = process.env.TOKEN_DECIMALS || "8";
  const reserveRatio = process.env.TOKEN_RESERVE_RATIO || "50";
  const initialReserveApt = process.env.TOKEN_INITIAL_RESERVE || "0.05";
  const thresholdUsd = process.env.TOKEN_THRESHOLD_USD || "75000";

  console.log("📝 Creating pool with parameters:");
  console.log(`   Name: ${name}`);
  console.log(`   Ticker: ${ticker}`);
  console.log(`   Image: ${imageUri}`);
  console.log(`   Description: ${description || '(none)'}`);
  console.log(`   Website: ${website || '(none)'}`);
  console.log(`   Twitter: ${twitter || '(none)'}`);
  console.log(`   Telegram: ${telegram || '(none)'}`);
  console.log(`   Discord: ${discord || '(none)'}`);
  console.log(`   Max Supply: ${maxSupplyStr || 'unlimited'}`);
  console.log(`   Decimals: ${decimals}`);
  console.log(`   Reserve Ratio: ${reserveRatio}%`);
  console.log(`   Initial Reserve: ${initialReserveApt} APT`);
  console.log(`   Threshold: $${thresholdUsd}\n`);

  // Convert inputs - handle Option types correctly
  const maxSupply = maxSupplyStr.trim() ? [BigInt(maxSupplyStr)] : [];
  const decimalsNum = parseInt(decimals);
  const reserveRatioNum = parseInt(reserveRatio);
  const initialReserveOctas = Math.floor(parseFloat(initialReserveApt) * 100000000);
  const thresholdCents = thresholdUsd.trim() ? [parseInt(thresholdUsd) * 100] : [];

  console.log("\n🔨 Creating pool...\n");

  try {
    // In SDK v1.39.0, Option types should be passed as:
    // - Some(value): pass the value directly (not in an array)
    // - None: pass undefined
    
    console.log("🔍 Building transaction with SDK v1.39.0 Option handling...");
    
    // Build arguments - Option<T> uses value or undefined, not arrays
    const functionArguments = [
      name,                                          // String
      ticker,                                        // String
      imageUri,                                      // String
      description.trim() || undefined,               // Option<String>
      website.trim() || undefined,                   // Option<String>
      twitter.trim() || undefined,                   // Option<String>
      telegram.trim() || undefined,                  // Option<String>
      discord.trim() || undefined,                   // Option<String>
      maxSupplyStr.trim() ? BigInt(maxSupplyStr) : undefined,  // Option<u128>
      decimalsNum,                                   // u8
      reserveRatioNum,                               // u64
      initialReserveOctas,                           // u64
      thresholdUsd.trim() ? parseInt(thresholdUsd) * 100 : undefined  // Option<u64>
    ];

    console.log("🔍 Debug - Function arguments:", JSON.stringify(functionArguments, (key, value) =>
      typeof value === 'bigint' ? value.toString() : value
    , 2));

    const transaction = await aptos.transaction.build.simple({
      sender: account.accountAddress,
      data: {
        function: `${contractAddress}::launchpad_v2::create_pool`,
        functionArguments,
      },
    });

    const committedTxn = await aptos.signAndSubmitTransaction({
      signer: account,
      transaction,
    });

    console.log("⏳ Waiting for transaction confirmation...\n");
    
    const result = await aptos.waitForTransaction({ 
      transactionHash: committedTxn.hash 
    });

    console.log("✅ Pool created successfully!\n");
    console.log(`📝 Transaction: ${committedTxn.hash}`);
    console.log(`🔗 Explorer: https://explorer.aptoslabs.com/txn/${committedTxn.hash}?network=testnet\n`);
    
    // Try to get the pool ID from events
    if (result.success) {
      console.log("🎉 Pool creation successful!");
      console.log("\nℹ️  To get your pool ID, run:");
      console.log(`   aptos move view --function-id ${contractAddress}::launchpad_v2::get_pools --profile testnet\n`);
    }

  } catch (error: any) {
    console.error("❌ Error creating pool:", error.message || error);
    process.exit(1);
  }
}

main().catch(console.error);
