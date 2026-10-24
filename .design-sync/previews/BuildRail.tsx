import { BuildRail, WorldBackdrop } from "@citybuilder/ui";

export const Rail = () => (
  <WorldBackdrop width={460} height={420} zoom={2}>
    <div style={{ position: "absolute", left: 16, top: 16, display: "flex", gap: 24 }}>
      <BuildRail active="Gather" />
      <BuildRail active="Road" hotkeys />
      <BuildRail phone active="Demolish" />
    </div>
  </WorldBackdrop>
);

export const Dock = () => (
  <WorldBackdrop width={460} height={180} zoom={2}>
    <div style={{ position: "absolute", left: 16, bottom: 16, display: "flex", flexDirection: "column", gap: 12 }}>
      <BuildRail placement="dock" active="Town" />
      <BuildRail placement="dock" phone />
    </div>
  </WorldBackdrop>
);
