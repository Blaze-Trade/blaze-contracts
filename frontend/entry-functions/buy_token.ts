import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";
// Internal utils
import { convertAmountFromHumanReadableToOnChain } from "@/utils/helpers";

export type BuyTokenArguments = {
  faObj: string; // The fungible asset object address
  amount: number; // Amount of tokens to buy
  decimals: number; // Token decimals
};

export const buyToken = (args: BuyTokenArguments): InputTransactionData => {
  const { faObj, amount, decimals } = args;
  return {
    data: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::buy_token`,
      typeArguments: [],
      functionArguments: [
        faObj,
        convertAmountFromHumanReadableToOnChain(amount, decimals)
      ],
    },
  };
};
