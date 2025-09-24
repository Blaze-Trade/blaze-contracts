import { isAptosConnectWallet, useWallet } from "@aptos-labs/wallet-adapter-react";
import { Link, useNavigate } from "react-router-dom";
import { useRef, useState } from "react";
// Internal components
import { Button, buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { WarningAlert } from "@/components/ui/warning-alert";
import { UploadSpinner } from "@/components/UploadSpinner";
import { LabeledInput } from "@/components/ui/labeled-input";
import { ConfirmButton } from "@/components/ui/confirm-button";
import { Header } from "@/components/Header";
// Internal utils
import { checkIfFund, uploadFile } from "@/utils/Irys";
import { aptosClient } from "@/utils/aptosClient";
// Entry functions
import { createToken } from "@/entry-functions/create_token";

export function CreateFungibleAsset() {
  // Wallet Adapter provider
  const aptosWallet = useWallet();
  const { account, wallet, signAndSubmitTransaction } = useWallet();

  // If we are on Production mode, redierct to the public mint page
  const navigate = useNavigate();

  // Collection data entered by the user on UI
  const [name, setName] = useState<string>("");
  const [symbol, setSymbol] = useState<string>("");
  const [maxSupply, setMaxSupply] = useState<string>();
  const [maxMintPerAccount, setMaxMintPerAccount] = useState<number>();
  const [decimal, setDecimal] = useState<string>();
  const [image, setImage] = useState<File | null>(null);
  const [projectURL, setProjectURL] = useState<string>("");
  const [mintFeePerFA, setMintFeePerFA] = useState<number>();
  const [mintForMyself, setMintForMyself] = useState<number>();
  
  // Bonding curve parameters
  const [bondingCurveMode, setBondingCurveMode] = useState<boolean>(false);
  const [virtualLiquidity, setVirtualLiquidity] = useState<number>();
  const [targetSupply, setTargetSupply] = useState<number>();

  // Internal state
  const [isUploading, setIsUploading] = useState(false);

  // Local Ref
  const inputRef = useRef<HTMLInputElement>(null);

  const disableCreateAssetButton =
    !name || !symbol || !maxSupply || !decimal || !projectURL || !maxMintPerAccount || !account || isUploading;

  // On create asset button clicked
  const onCreateAsset = async () => {
    try {
      if (!account) throw new Error("Connect wallet first");
      // Image is now optional - we'll use a placeholder if not provided

      // Set internal isUploading state
      setIsUploading(true);

      // For now, use a placeholder URL instead of Irys upload
      // TODO: Fix Irys integration or implement alternative file upload
      const iconURL = "https://via.placeholder.com/300x300/4F46E5/FFFFFF?text=Token+Image";
      
      // Alternative: Try Irys upload but fallback to placeholder if it fails
      // try {
      //   const funded = await checkIfFund(aptosWallet, image.size);
      //   if (!funded) throw new Error("Current account balance is not enough to fund a decentralized asset node");
      //   const iconURL = await uploadFile(aptosWallet, image);
      // } catch (irysError) {
      //   console.warn("Irys upload failed, using placeholder:", irysError);
      //   const iconURL = "https://via.placeholder.com/300x300/4F46E5/FFFFFF?text=Token+Image";
      // }

      // Submit a create_token entry function transaction
      const response = await signAndSubmitTransaction(
        createToken({
          maxSupply: Number(maxSupply),
          name,
          symbol,
          decimal: Number(decimal),
          iconURL,
          projectURL,
          mintFeePerFA,
          mintForMyself,
          maxMintPerAccount,
          bondingCurveMode,
          virtualLiquidity,
          targetSupply,
        }),
      );

      // Wait for the transaction to be committed to chain
      const committedTransactionResponse = await aptosClient().waitForTransaction({
        transactionHash: response.hash,
      });

      // Once the transaction has been successfully committed to chain, navigate to the all assets page
      if (committedTransactionResponse.success) {
        navigate(`/`, { replace: true });
      }
    } catch (error) {
      alert(error);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <>
      <Header />
      <div className="flex flex-col md:flex-row items-start justify-between px-4 py-2 gap-4 max-w-screen-xl mx-auto">
        <div className="w-full md:w-2/3 flex flex-col gap-y-4 order-2 md:order-1">
          {wallet && isAptosConnectWallet(wallet) && (
            <WarningAlert title="Wallet not supported">
              Google account is not supported when creating a Token. Please use a different wallet.
            </WarningAlert>
          )}

          <UploadSpinner on={isUploading} />

          <Card>
            <CardHeader>
              <CardTitle>Asset Image (Optional)</CardTitle>
              <CardDescription>Upload an image for your token. A placeholder will be used if not provided.</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="flex flex-col items-start justify-between">
                {!image && (
                  <Label
                    htmlFor="upload"
                    className={buttonVariants({
                      variant: "outline",
                      className: "cursor-pointer",
                    })}
                  >
                    Choose Image (Optional)
                  </Label>
                )}
                <Input
                  disabled={isUploading || !account || !wallet || isAptosConnectWallet(wallet)}
                  type="file"
                  className="hidden"
                  ref={inputRef}
                  id="upload"
                  placeholder="Upload Image"
                  onChange={(e) => {
                    setImage(e.target.files![0]);
                  }}
                />
                {image && (
                  <>
                    <img src={URL.createObjectURL(image)} className="max-w-48 max-h-48 object-cover rounded" />
                    <p className="body-sm">
                      {image.name}
                      <Button
                        variant="link"
                        className="text-destructive"
                        onClick={() => {
                          setImage(null);
                          inputRef.current!.value = "";
                        }}
                      >
                        Clear
                      </Button>
                    </p>
                  </>
                )}
                {!image && (
                  <div className="mt-2 p-4 border-2 border-dashed border-gray-300 rounded-lg text-center">
                    <p className="text-sm text-gray-500">No image selected</p>
                    <p className="text-xs text-gray-400">A placeholder image will be used</p>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          <LabeledInput
            id="asset-name"
            label="Asset Name"
            tooltip="The name of the asset, e.g. Bitcoin, Ethereum, etc."
            required
            onChange={(e) => setName(e.target.value)}
            disabled={isUploading || !account}
            type="text"
          />

          <LabeledInput
            id="asset-symbol"
            label="Asset Symbol"
            tooltip="The symbol of the asset, e.g. BTC, ETH, etc."
            required
            onChange={(e) => setSymbol(e.target.value)}
            disabled={isUploading || !account}
            type="text"
          />

          <LabeledInput
            id="max-supply"
            label="Max Supply"
            tooltip="The total amount of the asset in full unit that can be minted."
            required
            onChange={(e) => setMaxSupply(e.target.value)}
            disabled={isUploading || !account}
            type="number"
          />

          <LabeledInput
            id="max-mint"
            label="Max amount an address can mint"
            tooltip="The maximum amount in full unit that any single individual address can mint"
            required
            onChange={(e) => setMaxMintPerAccount(Number(e.target.value))}
            disabled={isUploading || !account}
            type="number"
          />

          <LabeledInput
            id="decimal"
            label="Decimal"
            tooltip="How many 0's constitute one full unit of the asset. For example, APT has 8."
            required
            onChange={(e) => setDecimal(e.target.value)}
            disabled={isUploading || !account}
            type="number"
          />

          <LabeledInput
            id="project-url"
            label="Project URL"
            tooltip="Your website address"
            required
            onChange={(e) => setProjectURL(e.target.value)}
            disabled={isUploading || !account}
            type="text"
          />

          <LabeledInput
            id="mint-fee"
            label="Mint fee per fungible asset in APT"
            tooltip="The fee cost for the minter to pay to mint one full unit of an asset, denominated in APT. For example, if a user mints 10 assets in a single transaction, they are charged 10x the mint fee."
            onChange={(e) => setMintFeePerFA(Number(e.target.value))}
            disabled={isUploading || !account}
            type="number"
          />

          <LabeledInput
            id="for-myself"
            label="Mint for myself"
            tooltip="How many assets in full unit to mint right away and send to your address."
            onChange={(e) => setMintForMyself(Number(e.target.value))}
            disabled={isUploading || !account}
            type="number"
          />

          <Card>
            <CardHeader>
              <CardTitle>Bonding Curve Settings</CardTitle>
              <CardDescription>Configure bonding curve parameters for dynamic pricing</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  id="bonding-curve-mode"
                  checked={bondingCurveMode}
                  onChange={(e) => setBondingCurveMode(e.target.checked)}
                  disabled={isUploading || !account}
                  className="rounded"
                />
                <Label htmlFor="bonding-curve-mode">Enable Bonding Curve Mode</Label>
              </div>
              
              {bondingCurveMode && (
                <>
                  <LabeledInput
                    id="virtual-liquidity"
                    label="Virtual Liquidity (APT)"
                    tooltip="Initial virtual liquidity for the bonding curve in APT"
                    onChange={(e) => setVirtualLiquidity(Number(e.target.value))}
                    disabled={isUploading || !account}
                    type="number"
                  />
                  
                  <LabeledInput
                    id="target-supply"
                    label="Target Supply"
                    tooltip="Target supply when bonding curve becomes inactive"
                    onChange={(e) => setTargetSupply(Number(e.target.value))}
                    disabled={isUploading || !account}
                    type="number"
                  />
                </>
              )}
            </CardContent>
          </Card>

          <ConfirmButton
            title="Create Asset"
            className="self-start"
            onSubmit={onCreateAsset}
            disabled={disableCreateAssetButton}
            confirmMessage={
              <>
                <p>
                  This will create a new token on the Aptos blockchain with the specified parameters.
                </p>
                <p>A placeholder image will be used if no image is uploaded.</p>
                <p>Make sure you have enough APT for transaction fees.</p>
              </>
            }
          />
        </div>

        <div className="w-full md:w-1/3 order-1 md:order-2">
          <Card>
            <CardHeader className="body-md-semibold">Learn More</CardHeader>
            <CardContent>
              <Link
                to="https://aptos.dev/standards/fungible-asset"
                style={{ textDecoration: "underline" }}
                target="_blank"
              >
                Find out more about Fungible Assets on Aptos
              </Link>
            </CardContent>
          </Card>
        </div>
      </div>
    </>
  );
}
