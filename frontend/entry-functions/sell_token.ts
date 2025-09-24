import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";
// Internal utils
import { convertAmountFromHumanReadableToOnChain } from "@/utils/helpers";

export type SellTokenArguments = {
  faObj: string; // The fungible asset object address
  amount: number; // Amount of tokens to sell
  decimals: number; // Token decimals
};

export const sellToken = (args: SellTokenArguments): InputTransactionData => {
  const { faObj, amount, decimals } = args;
  console.log("sell_token amount", amount);
  return {
    data: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::sell_token`,
      typeArguments: [],
      functionArguments: [
        faObj,
        amount
      ],
    },
  };
};
