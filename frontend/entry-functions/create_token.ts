import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";
// Internal utils
import {
  APT_DECIMALS,
  convertAmountFromHumanReadableToOnChain,
  convertAmountFromOnChainToHumanReadable,
} from "@/utils/helpers";

export type CreateTokenArguments = {
  maxSupply: number; // The total amount of the asset in full unit that can be minted.
  name: string; // The name of the asset
  symbol: string; // The symbol of the asset
  decimal: number; // How many 0's constitute one full unit of the asset. For example, APT has 8.
  iconURL: string; // The asset icon URL
  projectURL: string; // Your project URL (i.e https://mydomain.com)
  mintFeePerFA?: number; // The fee cost for the minter to pay to mint one full unit of an asset, denominated in APT. For example, if a user mints 10 assets in a single transaction, they are charged 10x the mint fee.
  mintForMyself?: number; // How many assets in full unit to mint right away and send to the signer address.
  maxMintPerAccount?: number; // The maximum amount in full unit that any single individual address can mint
  // New bonding curve parameters
  bondingCurveMode: boolean; // Whether to use bonding curve mode
  virtualLiquidity?: number; // Virtual liquidity for bonding curve (in APT)
  targetSupply?: number; // Target supply for bonding curve
};

export const createToken = (args: CreateTokenArguments): InputTransactionData => {
  const { 
    maxSupply, 
    name, 
    symbol, 
    decimal, 
    iconURL, 
    projectURL, 
    mintFeePerFA, 
    mintForMyself, 
    maxMintPerAccount,
    bondingCurveMode,
    virtualLiquidity,
    targetSupply
  } = args;
  
  return {
    data: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::create_token`,
      typeArguments: [],
      functionArguments: [
        convertAmountFromHumanReadableToOnChain(maxSupply, decimal),
        name,
        symbol,
        decimal,
        iconURL,
        projectURL,
        mintFeePerFA
          ? convertAmountFromOnChainToHumanReadable(
              convertAmountFromHumanReadableToOnChain(mintFeePerFA, APT_DECIMALS),
              decimal,
            )
          : 0,
        mintForMyself ? convertAmountFromHumanReadableToOnChain(mintForMyself, decimal) : 0,
        maxMintPerAccount ? convertAmountFromHumanReadableToOnChain(maxMintPerAccount, decimal) : 0,
        bondingCurveMode,
        virtualLiquidity ? convertAmountFromHumanReadableToOnChain(virtualLiquidity, APT_DECIMALS) : 0,
        targetSupply ? convertAmountFromHumanReadableToOnChain(targetSupply, decimal) : 0,
      ],
    },
  };
};
