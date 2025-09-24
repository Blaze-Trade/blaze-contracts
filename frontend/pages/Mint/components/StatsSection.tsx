import { Card } from "@/components/ui/card";
import { clampNumber } from "@/utils/clampNumber";
import { useGetAssetData } from "../../../hooks/useGetAssetData";
import { getBondingCurve } from "@/view-functions/bondingCurve";
import { getLiquidityPool } from "@/view-functions/liquidityPool";
import { useState, useEffect } from "react";

interface StatsSectionProps {
  faAddress?: string;
}

export const StatsSection: React.FC<StatsSectionProps> = ({ faAddress }: StatsSectionProps) => {
  const { data } = useGetAssetData(faAddress);
  const [bondingCurveData, setBondingCurveData] = useState<any>(null);
  const [liquidityPoolData, setLiquidityPoolData] = useState<any>(null);

  useEffect(() => {
    if (faAddress) {
      getBondingCurve({ faObj: faAddress }).then(setBondingCurveData);
      getLiquidityPool().then(setLiquidityPoolData);
    }
  }, [faAddress]);

  if (!data) return null;
  const { maxSupply, currentSupply, uniqueHolders } = data;

  const stats = [
    { title: "Max Supply", value: maxSupply },
    { title: "Current Supply", value: currentSupply },
    { title: "Unique Holders", value: uniqueHolders },
  ];

  // Add bonding curve stats if active
  if (bondingCurveData?.is_active) {
    stats.push(
      { title: "Virtual Liquidity", value: `${(bondingCurveData.virtual_liquidity / 1e8).toFixed(2)} APT` },
      { title: "Target Supply", value: bondingCurveData.target_supply },
      { title: "Bonding Curve Status", value: "Active" }
    );
  }

  // Add liquidity pool stats
  if (liquidityPoolData) {
    stats.push(
      { title: "Total APT Collected", value: `${(liquidityPoolData.total_apt_collected / 1e8).toFixed(2)} APT` },
      { title: "Total APT Paid Out", value: `${(liquidityPoolData.total_apt_paid_out / 1e8).toFixed(2)} APT` }
    );
  }

  return (
    <section className="stats-container px-4 max-w-screen-xl mx-auto w-full">
      <ul className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {stats.map(({ title, value }) => (
          <li key={title + " " + value}>
            <Card className="py-2 px-4" shadow="md">
              <p className="label-sm">{title}</p>
              <p className="heading-sm">{typeof value === 'string' ? value : clampNumber(value)}</p>
            </Card>
          </li>
        ))}
      </ul>
    </section>
  );
};
