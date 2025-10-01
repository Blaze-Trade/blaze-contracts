import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";

export type JoinQuestArguments = {
  questId: number;
};

export const joinQuest = (args: JoinQuestArguments): InputTransactionData => {
  const { questId } = args;
  return {
    data: {
      function: `${import.meta.env.VITE_QUEST_MODULE_ADDRESS}::quest_staking::join_quest`,
      typeArguments: [],
      functionArguments: [questId],
    },
  };
};
