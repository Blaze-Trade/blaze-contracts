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
  targetSupply: number; // Target supply for bonding curve
  virtualLiquidity: number; // Virtual liquidity for bonding curve (in APT)
  curveExponent: number; // Curve exponent for bonding curve (typically 2)
  maxMintPerAccount?: number; // The maximum amount in full unit that any single individual address can mint
};

export const createToken = (args: CreateTokenArguments): InputTransactionData => {
  const { 
    maxSupply, 
    name, 
    symbol, 
    decimal, 
    iconURL, 
    projectURL, 
    targetSupply,
    virtualLiquidity,
    curveExponent,
    maxMintPerAccount
  } = args;
  
  return {
    data: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::create_token`,
      typeArguments: [],
      functionArguments: [
        convertAmountFromHumanReadableToOnChain(maxSupply, decimal), // max_supply: Option<u128>
        name, // name: String
        symbol, // symbol: String
        decimal, // decimals: u8
        iconURL, // icon_uri: String
        projectURL, // project_uri: String
        convertAmountFromHumanReadableToOnChain(targetSupply, decimal), // target_supply: u64
        convertAmountFromHumanReadableToOnChain(virtualLiquidity, APT_DECIMALS), // virtual_liquidity: u64
        curveExponent, // curve_exponent: u64
        maxMintPerAccount > 0 ? convertAmountFromHumanReadableToOnChain(maxMintPerAccount, decimal) : 0, // mint_limit_per_addr: Option<u64>
      ],
    },
  };
};
