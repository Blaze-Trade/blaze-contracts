require("dotenv").config();
const fs = require("node:fs");
const yaml = require("js-yaml");
const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

const config = yaml.load(fs.readFileSync("./.aptos/config.yaml", "utf8"));
const accountAddress = config["profiles"]["quest_staking"]["account"];

async function publishQuestStaking() {
  const move = new cli.Move();

  try {
    console.log("🚀 Publishing Quest Staking contract to devnet...");
    console.log(`📝 Account: ${accountAddress}`);
    
    const response = await move.createObjectAndPublishPackage({
      packageDirectoryPath: "quest-staking/move",
      addressName: "quest_staking_addr",
      namedAddresses: {
        // Publish module to account address
        quest_staking_addr: accountAddress,
      },
      profile: "quest_staking",
    });

    console.log("✅ Contract published successfully!");
    console.log(`📦 Object Address: ${response.objectAddress}`);
    console.log(`🔗 Transaction Hash: ${response.transactionHash}`);

    // Update .env file with the new module address
    const filePath = "frontend/.env";
    let envContent = "";

    // Check .env file exists and read it
    if (fs.existsSync(filePath)) {
      envContent = fs.readFileSync(filePath, "utf8");
    }

    // Regular expression to match the VITE_QUEST_MODULE_ADDRESS variable
    const regex = /^VITE_QUEST_MODULE_ADDRESS=.*$/m;
    const newEntry = `VITE_QUEST_MODULE_ADDRESS=${response.objectAddress}`;

    // Check if VITE_QUEST_MODULE_ADDRESS is already defined
    if (envContent.match(regex)) {
      // If the variable exists, replace it with the new value
      envContent = envContent.replace(regex, newEntry);
    } else {
      // If the variable does not exist, append it
      envContent += `\n${newEntry}`;
    }

    // Write the updated content back to the .env file
    fs.writeFileSync(filePath, envContent, "utf8");
    
    console.log("📝 Updated frontend/.env with new module address");
    console.log("\n🎉 Deployment complete! You can now use the quest management page.");
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

publishQuestStaking();
