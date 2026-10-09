import { PlacementHUD, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={300} height={270} zoom={1} buildings={[]}>
    <div style={{ position: "absolute", left: 20, top: 10 }}>{children}</div>
  </WorldBackdrop>
);

export const Valid = () => (
  <OnMap>
    <PlacementHUD building="house" />
  </OnMap>
);

export const Invalid = () => (
  <OnMap>
    <PlacementHUD building="bakery" valid={false} />
  </OnMap>
);

export const MapEdge = () => (
  <OnMap>
    <PlacementHUD building="lumberjack-hut" disabled={["ne", "nw"]} />
  </OnMap>
);
