import { PerfOverlay, WorldBackdrop } from "@citybuilder/ui";

export const Readings = () => (
  <WorldBackdrop width={320} height={80} zoom={2}>
    <div style={{ padding: 16, display: "flex", gap: 12 }}>
      <PerfOverlay tickCount={18234} tickMs={1.42} />
      <PerfOverlay tickCount={18235} tickMs={7.9} />
      <PerfOverlay tickCount={0} />
    </div>
  </WorldBackdrop>
);
