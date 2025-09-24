import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { AccountAddress } from "@aptos-labs/ts-sdk";
import { useQuery } from "@tanstack/react-query";
// Internal utils
import { aptosClient } from "@/utils/aptosClient";
import { convertAmountFromOnChainToHumanReadable } from "@/utils/helpers";
// Internal constants
import { MODULE_ADDRESS } from "@/constants";

export interface FungibleAsset {
  maximum_v2: number;
  supply_v2: number;
  name: string;
  symbol: string;
  decimals: number;
  asset_type: string;
  icon_uri: string;
}

interface MintQueryResult {
  fungible_asset_metadata: Array<FungibleAsset>;
  current_fungible_asset_balances_aggregate: {
    aggregate: {
      count: number;
    };
  };
  current_fungible_asset_balances: Array<{
    amount: number;
  }>;
}

interface MintData {
  maxSupply: number;
  currentSupply: number;
  uniqueHolders: number;
  yourBalance: number;
  totalAbleToMint: number;
  asset: FungibleAsset;
  isMintActive: boolean;
}

async function getMintLimit(fa_address: string): Promise<number> {
  try {
    const mintLimitRes = await aptosClient().view<[boolean, number]>({
      payload: {
        function: `${AccountAddress.from(MODULE_ADDRESS)}::launchpad::get_mint_limit`,
        functionArguments: [fa_address],
      },
    });

    // Return the limit if it exists, otherwise return 0
    return mintLimitRes[0] ? mintLimitRes[1] : 0;
  } catch (error) {
    console.error("Error getting mint limit:", error);
    return 0; // Default to 0 if there's an error
  }
}

/**
 * A react hook to get fungible asset data.
 */
export function useGetAssetData(fa_address?: string) {
  const { account } = useWallet();

  return useQuery({
    queryKey: ["app-state", fa_address],
    refetchInterval: 1000 * 60, // Reduced from 30s to 60s to avoid rate limiting
    retry: 3, // Retry failed requests
    retryDelay: 5000, // Wait 5s between retries
    queryFn: async () => {
      try {
        if (!fa_address) return null;

        const res = await aptosClient().queryIndexer<MintQueryResult>({
          query: {
            variables: {
              fa_address,
              account: account?.address.toString() ?? "",
            },
            query: `
            query FungibleQuery($fa_address: String, $account: String) {
              fungible_asset_metadata(where: {asset_type: {_eq: $fa_address}}) {
                maximum_v2
                supply_v2
                name
                symbol
                decimals
                asset_type
                icon_uri
              }
              current_fungible_asset_balances_aggregate(
                distinct_on: owner_address
                where: {asset_type: {_eq: $fa_address}}
              ) {
                aggregate {
                  count
                }
              }
              current_fungible_asset_balances(
                where: {owner_address: {_eq: $account}, asset_type: {_eq: $fa_address}}
                distinct_on: asset_type
                limit: 1
              ) {
                amount
              }
            }`,
          },
        });

        const asset = res.fungible_asset_metadata[0];
        if (!asset) {
          console.warn(`No asset found for address: ${fa_address}`);
          return null;
        }

        return {
          asset,
          maxSupply: convertAmountFromOnChainToHumanReadable(asset.maximum_v2 ?? 0, asset.decimals),
          currentSupply: convertAmountFromOnChainToHumanReadable(asset.supply_v2 ?? 0, asset.decimals),
          uniqueHolders: res.current_fungible_asset_balances_aggregate.aggregate.count ?? 0,
          totalAbleToMint: convertAmountFromOnChainToHumanReadable(await getMintLimit(fa_address), asset.decimals),
          yourBalance: convertAmountFromOnChainToHumanReadable(
            res.current_fungible_asset_balances[0]?.amount ?? 0,
            asset.decimals,
          ),
          isMintActive: asset.maximum_v2 > asset.supply_v2,
        } satisfies MintData;
      } catch (error) {
        console.error("Error fetching asset data:", error);
        
        // If it's a rate limit error, return a minimal data structure
        if (error instanceof Error && error.message.includes("rate limit")) {
          console.warn("Rate limit exceeded, returning minimal data");
          return {
            asset: {
              maximum_v2: 0,
              supply_v2: 0,
              name: "Unknown",
              symbol: "UNK",
              decimals: 8,
              asset_type: fa_address!,
              icon_uri: ""
            },
            maxSupply: 0,
            currentSupply: 0,
            uniqueHolders: 0,
            totalAbleToMint: 0,
            yourBalance: 0,
            isMintActive: false,
          };
        }
        
        return null;
      }
    },
  });
}
