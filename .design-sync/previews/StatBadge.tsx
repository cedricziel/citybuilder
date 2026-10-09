import { StatBadge, Glass, WorldBackdrop } from "@citybuilder/ui";

export const HUDStats = () => (
  <WorldBackdrop width={420} height={110} zoom={2}>
    <Glass radius={12} padding="8px 16px" style={{ margin: 16, display: "flex", gap: 16 }}>
      <StatBadge label="Money" value="$1,250" />
      <StatBadge label="Population" value="Pop. 84" />
      <StatBadge label="Island" value="Greenhold" />
    </Glass>
  </WorldBackdrop>
);

export const Negative = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <StatBadge label="Money" value="-$40" />
    <StatBadge label="Population" value="Pop. 0" />
  </div>
);
