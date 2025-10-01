import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";

export type SelectPortfolioArguments = {
  questId: number;
  tokenAddresses: string[];
  amountsUsdc: number[]; // amounts in USDC (6 decimals)
};

export const selectPortfolio = (args: SelectPortfolioArguments): InputTransactionData => {
  const { questId, tokenAddresses, amountsUsdc } = args;
  return {
    data: {
      function: `${import.meta.env.VITE_QUEST_MODULE_ADDRESS}::quest_staking::select_portfolio`,
      typeArguments: [],
      functionArguments: [questId, tokenAddresses, amountsUsdc],
    },
  };
};
