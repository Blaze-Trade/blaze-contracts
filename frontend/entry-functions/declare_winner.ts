import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";

export type DeclareWinnerArguments = {
  questId: number;
  winner: string; // winner address
};

export const declareWinner = (args: DeclareWinnerArguments): InputTransactionData => {
  const { questId, winner } = args;
  return {
    data: {
      function: `${import.meta.env.VITE_QUEST_MODULE_ADDRESS}::quest_staking::declare_winner`,
      typeArguments: [],
      functionArguments: [questId, winner],
    },
  };
};
