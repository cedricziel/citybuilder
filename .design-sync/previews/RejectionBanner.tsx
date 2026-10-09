import { RejectionBanner, WorldBackdrop } from "@citybuilder/ui";

export const Reasons = () => (
  <WorldBackdrop width={360} height={130} zoom={2}>
    <div style={{ padding: 16, display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
      <RejectionBanner message="Needs a road" />
      <RejectionBanner message="Not enough money" />
      <RejectionBanner message="Tile is occupied" />
    </div>
  </WorldBackdrop>
);
