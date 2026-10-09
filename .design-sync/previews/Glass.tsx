import { Glass, WorldBackdrop } from "@citybuilder/ui";

export const Shapes = () => (
  <WorldBackdrop width={560} height={200} zoom={2}>
    <div style={{ display: "flex", alignItems: "center", gap: 16, padding: 24 }}>
      <Glass radius={12} padding="12px 16px">
        <div className="cb-headline">Rounded 12</div>
        <div className="cb-caption cb-secondary">HUD, palette</div>
      </Glass>
      <Glass radius={8} padding="8px 12px" className="cb-caption">Rounded 8</Glass>
      <Glass shape="capsule" padding="4px 10px" className="cb-caption2">Capsule</Glass>
      <Glass shape="circle" style={{ width: 38, height: 38 }} />
    </div>
  </WorldBackdrop>
);

export const DarkMaterial = () => (
  <WorldBackdrop width={560} height={140} zoom={2} season="winter">
    <div className="cb-theme-dark" style={{ padding: 24, color: "var(--cb-label)" }}>
      <Glass radius={12} padding="12px 16px">
        <div className="cb-headline">Thin material, dark</div>
        <div className="cb-caption cb-secondary">The same panel in dark appearance</div>
      </Glass>
    </div>
  </WorldBackdrop>
);
