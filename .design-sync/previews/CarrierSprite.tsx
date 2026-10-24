import { CarrierSprite, type CarrierLoad } from "@citybuilder/ui";

const loads: CarrierLoad[] = ["logs", "sack", "crate", "barrel"];

export const Loads = () => (
  <div style={{ display: "flex", gap: 16, alignItems: "flex-end" }}>
    {loads.map((load) => (
      <div key={load} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
        <CarrierSprite load={load} scale={2} />
        <span className="cb-caption2 cb-mono cb-secondary">{load}</span>
      </div>
    ))}
  </div>
);

export const Facings = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <CarrierSprite load="logs" facing="ne" scale={2} />
    <CarrierSprite load="logs" facing="nw" scale={2} />
    <CarrierSprite load="logs" facing="se" scale={2} />
    <CarrierSprite load="logs" facing="sw" scale={2} />
  </div>
);
