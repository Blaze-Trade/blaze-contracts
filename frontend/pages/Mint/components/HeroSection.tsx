import { FC, FormEvent, useState, useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
// Internal utils
import { truncateAddress } from "@/utils/truncateAddress";
// Internal components
import { Image } from "@/components/ui/image";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button, buttonVariants } from "@/components/ui/button";
import { Socials } from "@/pages/Mint/components/Socials";
// Internal hooks
import { useGetAssetData } from "../../../hooks/useGetAssetData";
// Internal utils
import { aptosClient } from "@/utils/aptosClient";
// Internal constants
import { NETWORK } from "@/constants";
// Internal assets
import Placeholder1 from "@/assets/placeholders/asset.png";
import ExternalLink from "@/assets/icons/external-link.svg";
import Copy from "@/assets/icons/copy.svg";
// Internal config
import { config } from "@/config";
// Internal entry functions
import { buyToken } from "@/entry-functions/buy_token";
import { sellToken } from "@/entry-functions/sell_token";
// Internal view functions
import { getBondingCurve, getBondingCurveMintCost, getBondingCurveSellPayout } from "@/view-functions/bondingCurve";

interface HeroSectionProps {
  faAddress?: string;
}

export const HeroSection: React.FC<HeroSectionProps> = ({ faAddress }: HeroSectionProps) => {
  const { data } = useGetAssetData(faAddress);
  const queryClient = useQueryClient();
  const { account, signAndSubmitTransaction } = useWallet();
  const [assetCount, setAssetCount] = useState<string>("1");
  const [error, setError] = useState<string | null>(null);
  const [bondingCurveData, setBondingCurveData] = useState<any>(null);
  const [costToBuy, setCostToBuy] = useState<number>(0);
  const [payoutToSell, setPayoutToSell] = useState<number>(0);
  const [isLoadingPrices, setIsLoadingPrices] = useState<boolean>(false);

  const { asset, totalAbleToMint = 0, yourBalance = 0, maxSupply = 0, currentSupply = 0 } = data ?? {
    asset: null,
    totalAbleToMint: 0,
    yourBalance: 0,
    maxSupply: 0,
    currentSupply: 0
  };

  // Fetch bonding curve data when asset changes
  useEffect(() => {
    if (faAddress) {
      getBondingCurve({ faObj: faAddress })
        .then(setBondingCurveData)
        .catch(error => {
          console.error("Error fetching bonding curve data:", error);
          setBondingCurveData(null);
        });
    }
  }, [faAddress]);

  // Update prices when amount changes
  useEffect(() => {
    if (faAddress && assetCount && bondingCurveData?.is_active) {
      setIsLoadingPrices(true);
      const amount = parseFloat(assetCount);
      if (!Number.isNaN(amount) && amount > 0) {
        Promise.all([
          getBondingCurveMintCost({ faObj: faAddress, amount }),
          getBondingCurveSellPayout({ faObj: faAddress, amount })
        ]).then(([cost, payout]) => {
          setCostToBuy(cost);
          setPayoutToSell(payout);
          setIsLoadingPrices(false);
        }).catch(error => {
          console.error("Error calculating prices:", error);
          setCostToBuy(0);
          setPayoutToSell(0);
          setIsLoadingPrices(false);
        });
      } else {
        setCostToBuy(0);
        setPayoutToSell(0);
        setIsLoadingPrices(false);
      }
    }
  }, [faAddress, assetCount, bondingCurveData]);

  const buyTokenAction = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!account) {
      return setError("Please connect your wallet");
    }

    if (!asset) {
      return setError("Asset not found");
    }

    if (!data?.isMintActive) {
      return setError("Minting is not available");
    }

    const amount = parseFloat(assetCount);
    if (Number.isNaN(amount) || amount <= 0) {
      return setError("Invalid amount");
    }

    try {
      const response = await signAndSubmitTransaction(
        buyToken({
          faObj: asset.asset_type,
          amount,
          decimals: asset.decimals,
        }),
      );
      await aptosClient().waitForTransaction({ transactionHash: response.hash });
      queryClient.invalidateQueries();
      setAssetCount("1");
    } catch (err: any) {
      setError(err.message || "Transaction failed");
    }
  };

  const sellTokenAction = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!account) {
      return setError("Please connect your wallet");
    }

    if (!asset) {
      return setError("Asset not found");
    }

    if (!bondingCurveData?.is_active) {
      return setError("Bonding curve is not active");
    }

    if (yourBalance < parseFloat(assetCount)) {
      return setError("Insufficient balance");
    }

    const amount = parseFloat(assetCount);
    if (Number.isNaN(amount) || amount <= 0) {
      return setError("Invalid amount");
    }

    try {
      const response = await signAndSubmitTransaction(
        sellToken({
          faObj: asset.asset_type,
          amount,
          decimals: asset.decimals,
        }),
      );
      await aptosClient().waitForTransaction({ transactionHash: response.hash });
      queryClient.invalidateQueries();
      setAssetCount("1");
    } catch (err: any) {
      setError(err.message || "Transaction failed");
    }
  };

  return (
    <section className="hero-container flex flex-col md:flex-row gap-6 px-4 max-w-screen-xl mx-auto w-full">
      <Image
        src={asset?.icon_uri ?? Placeholder1}
        rounded="full"
        className="basis-1/5 aspect-square object-cover self-center max-w-[300px]"
      />
      <div className="basis-4/5 flex flex-col gap-4">
        <h1 className="title-md">{asset?.name ?? config.defaultAsset?.name}</h1>
        <Socials />

        <Card>
          <CardContent fullPadding className="space-y-4">
            {/* Token Amount Input */}
            <div className="flex flex-col md:flex-row gap-4 items-center">
              <Input
                type="text"
                name="amount"
                value={assetCount}
                onChange={(e) => {
                  setAssetCount(e.target.value);
                }}
                placeholder="Amount to trade"
                className="flex-1"
              />
              <span className="text-sm text-gray-500">{asset?.symbol}</span>
            </div>

            {/* Price Information */}
            {bondingCurveData?.is_active && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
                <div className="text-center">
                  <p className="label-sm">Cost to Buy</p>
                  <p className="body-md font-semibold">
                    {isLoadingPrices ? "..." : `${(costToBuy / 1e8).toFixed(6)} APT`}
                  </p>
                </div>
                <div className="text-center">
                  <p className="label-sm">Payout to Sell</p>
                  <p className="body-md font-semibold">
                    {isLoadingPrices ? "..." : `${(payoutToSell / 1e8).toFixed(6)} APT`}
                  </p>
                </div>
              </div>
            )}

            {/* Action Buttons */}
            <div className="flex flex-col md:flex-row gap-4">
              <Button 
                onClick={buyTokenAction}
                className="flex-1"
                disabled={!data?.isMintActive || isLoadingPrices}
              >
                Buy Tokens
              </Button>
              {bondingCurveData?.is_active && (
                <Button 
                  onClick={sellTokenAction}
                  variant="outline"
                  className="flex-1"
                  disabled={yourBalance < parseFloat(assetCount) || isLoadingPrices}
                >
                  Sell Tokens
                </Button>
              )}
            </div>

            {/* Stats */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 pt-4 border-t">
              <div className="text-center">
                <p className="label-sm">Max Supply</p>
                <p className="body-md">{maxSupply} {asset?.symbol}</p>
              </div>
              <div className="text-center">
                <p className="label-sm">Current Supply</p>
                <p className="body-md">{currentSupply} {asset?.symbol}</p>
              </div>
              <div className="text-center">
                <p className="label-sm">Your Balance</p>
                <p className="body-md">{yourBalance} {asset?.symbol}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        {error && <p className="body-sm text-destructive">{error}</p>}

        <div className="flex gap-x-2 items-center flex-wrap justify-between">
          <p className="whitespace-nowrap body-sm-semibold">Address</p>

          <div className="flex gap-x-2">
            <AddressButton address={asset?.asset_type ?? ""} />
            <a
              className={buttonVariants({ variant: "link" })}
              target="_blank"
              href={`https://explorer.aptoslabs.com/account/${asset?.asset_type}?network=${NETWORK}`}
            >
              View on Explorer <Image src={ExternalLink} />
            </a>
          </div>
        </div>
      </div>
    </section>
  );
};

const AddressButton: FC<{ address: string }> = ({ address }) => {
  const [copied, setCopied] = useState(false);

  async function onCopy() {
    if (copied) return;
    await navigator.clipboard.writeText(address);
    setCopied(true);
    setTimeout(() => setCopied(false), 3000);
  }

  return (
    <Button onClick={onCopy} className="whitespace-nowrap flex gap-1 px-0 py-0" variant="link">
      {copied ? (
        "Copied!"
      ) : (
        <>
          {truncateAddress(address)}
          <Image src={Copy} className="dark:invert" />
        </>
      )}
    </Button>
  );
};
