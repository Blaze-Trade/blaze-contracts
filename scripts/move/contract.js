require("dotenv").config();
const fs = require("node:fs");
const yaml = require("js-yaml");
const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

const config = yaml.load(fs.readFileSync("./.aptos/config.yaml", "utf8"));
const accountAddress = config["profiles"][`${process.env.PROJECT_NAME}-${process.env.VITE_APP_NETWORK}`]["account"];

async function deployContract() {
  const move = new cli.Move();

  try {
    console.log("🔨 Compiling Move contract...");
    
    // First compile the contract
    await move.compile({
      packageDirectoryPath: "move",
      namedAddresses: {
        blaze_token_launchpad: accountAddress,
      },
    });
    
    console.log("✅ Contract compiled successfully!");
    console.log("🚀 Publishing contract to blockchain...");

    // Then publish the contract
    const response = await move.createObjectAndPublishPackage({
      packageDirectoryPath: "move",
      addressName: "blaze_token_launchpad",
      namedAddresses: {
        blaze_token_launchpad: accountAddress,
      },
      profile: `${process.env.PROJECT_NAME}-${process.env.VITE_APP_NETWORK}`,
    });

    console.log("✅ Contract published successfully!");
    console.log(`📍 Contract address: ${response.objectAddress}`);
    console.log(`🔗 Explorer: https://explorer.aptoslabs.com/object/${response.objectAddress}?network=${process.env.VITE_APP_NETWORK}`);

    // Update .env file with new contract address
    const filePath = ".env";
    let envContent = "";

    // Check .env file exists and read it
    if (fs.existsSync(filePath)) {
      envContent = fs.readFileSync(filePath, "utf8");
    }

    // Regular expression to match the VITE_MODULE_ADDRESS variable
    const regex = /^VITE_MODULE_ADDRESS=.*$/m;
    const newEntry = `VITE_MODULE_ADDRESS=${response.objectAddress}`;

    // Check if VITE_MODULE_ADDRESS is already defined
    if (envContent.match(regex)) {
      // If the variable exists, replace it with the new value
      envContent = envContent.replace(regex, newEntry);
    } else {
      // If the variable does not exist, append it
      envContent += `\n${newEntry}`;
    }

    // Write the updated content back to the .env file
    fs.writeFileSync(filePath, envContent, "utf8");
    console.log("📝 Updated .env file with new contract address");

    // Also update .env.local if it exists
    const localEnvPath = ".env.local";
    if (fs.existsSync(localEnvPath)) {
      let localEnvContent = fs.readFileSync(localEnvPath, "utf8");
      const localRegex = /^VITE_MODULE_ADDRESS=.*$/m;
      const localNewEntry = `VITE_MODULE_ADDRESS=${response.objectAddress}`;
      
      if (localEnvContent.match(localRegex)) {
        localEnvContent = localEnvContent.replace(localRegex, localNewEntry);
      } else {
        localEnvContent += `\n${localNewEntry}`;
      }
      
      fs.writeFileSync(localEnvPath, localEnvContent, "utf8");
      console.log("📝 Updated .env.local file with new contract address");
    }

  } catch (error) {
    console.error("❌ Error deploying contract:", error.message);
    process.exit(1);
  }
}

deployContract();
