import { AreaCountCapsule, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={460} height={90} zoom={2}>
    <div style={{ padding: 24, display: "flex", gap: 12, justifyContent: "center" }}>{children}</div>
  </WorldBackdrop>
);

export const Tones = () => (
  <OnMap>
    <AreaCountCapsule text="18 trees in reach" />
    <AreaCountCapsule text="3 trees in reach" tone="low" />
    <AreaCountCapsule text="No trees in reach" tone="none" />
  </OnMap>
);

export const MineSite = () => (
  <OnMap>
    <AreaCountCapsule text="Mine site: 4 rock tiles" />
    <AreaCountCapsule text="Mine site: 4 rock tiles" device="mac" />
  </OnMap>
);
