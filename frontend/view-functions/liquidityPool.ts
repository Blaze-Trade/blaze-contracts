import { aptosClient } from "@/utils/aptosClient";

export interface LiquidityPoolData {
  total_apt_collected: number;
  total_apt_paid_out: number;
}

export const getLiquidityPool = async (): Promise<LiquidityPoolData> => {
  const result = await aptosClient().view<[number, number]>({
    payload: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::get_liquidity_pool`,
      functionArguments: [],
    },
  });
  
  return {
    total_apt_collected: result[0],
    total_apt_paid_out: result[1],
  };
};

export const getAvailableLiquidity = async (): Promise<number> => {
  const result = await aptosClient().view<[number]>({
    payload: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::get_available_liquidity`,
      functionArguments: [],
    },
  });
  
  return result[0];
};
