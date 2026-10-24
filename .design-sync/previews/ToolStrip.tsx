import { ToolStrip, RejectionBanner, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children, h = 90 }: { children: React.ReactNode; h?: number }) => (
  <WorldBackdrop width={700} height={h} zoom={2}>
    <div style={{ position: "absolute", left: 16, right: 16, bottom: 16, display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
      {children}
    </div>
  </WorldBackdrop>
);

export const House = () => (
  <OnMap>
    <ToolStrip tool="House" art="house" cost={50} hint="Tap or drag to place house · No farm yet: residents need food" materials={[{ good: "planks", have: 18, need: 4 }]} />
  </OnMap>
);

export const Lumberjack = () => (
  <OnMap>
    <ToolStrip tool="Lumberjack" art="lumberjack-hut" cost={80} hint="Tap or drag to place lumberjack · 18 trees in reach" />
  </OnMap>
);

export const MissingMaterials = () => (
  <OnMap h={140}>
    <RejectionBanner message="Not enough planks" />
    <ToolStrip
      tool="Warehouse"
      art="warehouse"
      cost={200}
      hint="Click or drag to place warehouse"
      materials={[
        { good: "planks", have: 3, need: 6, status: "queueable" },
        { good: "wood", have: 0, need: 2 },
      ]}
    />
  </OnMap>
);

export const Demolish = () => (
  <OnMap>
    <ToolStrip tool="Demolish" hint="Tap a building to demolish" />
  </OnMap>
);
