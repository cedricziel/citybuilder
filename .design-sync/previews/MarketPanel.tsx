import { MarketPanel, WorldBackdrop, sampleMarketRows } from "@citybuilder/ui";

const OnMap = ({ children, h = 300 }: { children: React.ReactNode; h?: number }) => (
  <WorldBackdrop width={460} height={h} zoom={2}>
    <div style={{ position: "absolute", left: 16, top: 16 }}>{children}</div>
  </WorldBackdrop>
);

export const TownCenter = () => (
  <OnMap>
    <MarketPanel rows={sampleMarketRows} />
  </OnMap>
);

export const OtherGoods = () => (
  <OnMap h={380}>
    <MarketPanel
      rows={sampleMarketRows.slice(0, 2)}
      otherRows={[
        { good: "tea", text: "Tea — sell $14 (8 left)", sellable: true, canSell: false },
        { good: "coffee", text: "Coffee — sell $16 (8 left)", sellable: true, canSell: false },
      ]}
      showOtherGoods
    />
  </OnMap>
);
