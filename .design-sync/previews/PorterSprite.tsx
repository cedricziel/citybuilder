import { PorterSprite } from "@citybuilder/ui";

export const Loads = () => (
  <div style={{ display: "flex", gap: 16, alignItems: "flex-end" }}>
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
      <PorterSprite scale={2} />
      <span className="cb-caption2 cb-mono cb-secondary">to a house</span>
    </div>
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
      <PorterSprite empty scale={2} />
      <span className="cb-caption2 cb-mono cb-secondary">back to market</span>
    </div>
  </div>
);

export const Facings = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <PorterSprite facing="ne" scale={2} />
    <PorterSprite facing="nw" scale={2} />
    <PorterSprite facing="se" scale={2} />
    <PorterSprite facing="sw" scale={2} />
  </div>
);
