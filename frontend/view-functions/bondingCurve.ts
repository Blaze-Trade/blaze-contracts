import { aptosClient } from "@/utils/aptosClient";

export type BondingCurveArguments = {
  faObj: string;
};

export interface BondingCurveData {
  is_active: boolean;
  virtual_liquidity: number;
  target_supply: number;
  current_supply: number;
}

export const getBondingCurve = async (args: BondingCurveArguments): Promise<BondingCurveData> => {
  const { faObj } = args;
  const result = await aptosClient().view<[boolean, number, number, number]>({
    payload: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::get_bonding_curve`,
      functionArguments: [faObj],
    },
  });
  
  return {
    is_active: result[0],
    virtual_liquidity: result[1],
    target_supply: result[2],
    current_supply: result[3],
  };
};

export const getBondingCurvePrice = async (args: BondingCurveArguments): Promise<number> => {
  const { faObj } = args;
  const result = await aptosClient().view<[number]>({
    payload: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::get_bonding_curve_price`,
      functionArguments: [faObj],
    },
  });
  
  return result[0];
};

export const getBondingCurveMintCost = async (args: BondingCurveArguments & { amount: number }): Promise<number> => {
  const { faObj, amount } = args;
  const result = await aptosClient().view<[number]>({
    payload: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::get_bonding_curve_mint_cost`,
      functionArguments: [faObj, amount],
    },
  });
  
  return result[0];
};

export const getBondingCurveSellPayout = async (args: BondingCurveArguments & { amount: number }): Promise<number> => {
  const { faObj, amount } = args;
  const result = await aptosClient().view<[number]>({
    payload: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::launchpad::get_bonding_curve_sell_payout`,
      functionArguments: [faObj, amount],
    },
  });
  
  return result[0];
};
