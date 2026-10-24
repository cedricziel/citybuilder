import { Inspector, RivalMarketPanel, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={460} height={260} zoom={2}>
    <div style={{ position: "absolute", left: 16, top: 16, display: "flex", flexDirection: "column", gap: 8 }}>{children}</div>
  </WorldBackdrop>
);

export const RivalPort = () => (
  <OnMap>
    <Inspector lines={["Kind: port", "Owner: Ravenmoor", "State: operational"]} />
    <RivalMarketPanel sells={["Wood — $5 — 12 available", "Grain — $4 — 20 available"]} buys={["Tools — $22 — wants 20"]} />
  </OnMap>
);

export const Empty = () => (
  <OnMap>
    <RivalMarketPanel sells={[]} buys={[]} />
  </OnMap>
);
