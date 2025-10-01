import { aptosClient } from "@/utils/aptosClient";

export interface Quest {
  quest_id: number;
  name: string;
  admin: string;
  entry_fee: number;
  buy_in_time: number;
  result_time: number;
  status: "Active" | "Closed" | "Completed" | "Cancelled";
  participants: string[];
  total_pool: number;
  winner?: string;
  created_at: number;
}

export interface Participation {
  quest_id: number;
  user: string;
  portfolio?: {
    tokens: Array<{
      token_address: string;
      amount_usdc: number;
    }>;
    total_value_usdc: number;
    selected_at: number;
  };
  entry_fee_paid: number;
  joined_at: number;
}

export const getQuestInfo = async (questId: number): Promise<Quest> => {
  const response = await aptosClient().view({
    payload: {
      function: `${import.meta.env.VITE_QUEST_MODULE_ADDRESS}::quest_staking::get_quest_info`,
      typeArguments: [],
      functionArguments: [questId.toString()],
    },
  });
  
  return response[0] as Quest;
};

export const getAllQuests = async (): Promise<Quest[]> => {
  const response = await aptosClient().view({
    payload: {
      function: `${import.meta.env.VITE_QUEST_MODULE_ADDRESS}::quest_staking::get_all_quests`,
      typeArguments: [],
      functionArguments: [],
    },
  });
  
  return response[0] as Quest[];
};

export const getUserParticipation = async (user: string, questId: number): Promise<Participation> => {
  const response = await aptosClient().view({
    payload: {
      function: `${import.meta.env.VITE_QUEST_MODULE_ADDRESS}::quest_staking::get_user_participation`,
      typeArguments: [],
      functionArguments: [user, questId.toString()],
    },
  });
  
  return response[0] as Participation;
};

export const hasUserParticipated = async (user: string, questId: number): Promise<boolean> => {
  const response = await aptosClient().view({
    payload: {
      function: `${import.meta.env.VITE_QUEST_MODULE_ADDRESS}::quest_staking::has_user_participated`,
      typeArguments: [],
      functionArguments: [user, questId.toString()],
    },
  });
  
  return response[0] as boolean;
};

export const getQuestParticipants = async (questId: number): Promise<string[]> => {
  const response = await aptosClient().view({
    payload: {
      function: `${import.meta.env.VITE_QUEST_MODULE_ADDRESS}::quest_staking::get_quest_participants`,
      typeArguments: [],
      functionArguments: [questId.toString()],
    },
  });
  
  return response[0] as string[];
};
