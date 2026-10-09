import { CostBreakdown, HintCapsule, WorldBackdrop } from "@citybuilder/ui";

export const Affordable = () => (
  <WorldBackdrop width={360} height={70} zoom={2}>
    <div style={{ padding: 16 }}>
      <CostBreakdown lines={[{ good: "planks", have: 18, need: 4 }, { good: "wood", have: 42, need: 2 }]} />
    </div>
  </WorldBackdrop>
);

export const Shortfall = () => (
  <WorldBackdrop width={360} height={70} zoom={2}>
    <div style={{ padding: 16 }}>
      <CostBreakdown
        lines={[
          { good: "planks", have: 3, need: 6, status: "queueable" },
          { good: "tools", have: 0, need: 2, status: "blocked" },
          { good: "wood", have: 12, need: 4 },
        ]}
      />
    </div>
  </WorldBackdrop>
);

export const UnderCaption = () => (
  <WorldBackdrop width={360} height={100} zoom={2}>
    <div style={{ padding: 16, display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
      <HintCapsule>Tap or drag to place sawmill — $200</HintCapsule>
      <CostBreakdown lines={[{ good: "planks", have: 18, need: 4 }, { good: "tools", have: 1, need: 2 }]} />
    </div>
  </WorldBackdrop>
);
