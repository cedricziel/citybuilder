import { HintCapsule, WorldBackdrop } from "@citybuilder/ui";

export const Captions = () => (
  <WorldBackdrop width={360} height={130} zoom={2}>
    <div style={{ padding: 16, display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
      <HintCapsule>Tap or drag to place house — $120</HintCapsule>
      <HintCapsule>Tap or drag to demolish</HintCapsule>
      <HintCapsule>Tap a tile to inspect</HintCapsule>
    </div>
  </WorldBackdrop>
);
