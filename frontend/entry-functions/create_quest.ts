import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";

export type CreateQuestArguments = {
  name: string;
  entryFee: number; // in APT (octas)
  buyInTime: number; // seconds from now
  resultTime: number; // seconds from now
};

export const createQuest = (args: CreateQuestArguments): InputTransactionData => {
  const { name, entryFee, resultTime, buyInTime } = args;
  return {
    data: {
      function: `${import.meta.env.VITE_QUEST_MODULE_ADDRESS}::quest_staking::create_quest`,
      typeArguments: [],
      functionArguments: [
        name,
        entryFee,
        buyInTime,
        resultTime,
      ],
    },
  };
};
