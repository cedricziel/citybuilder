import { AnimalSprite } from "@citybuilder/ui";

const Cell = ({ label, children }: { label: string; children: React.ReactNode }) => (
  <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
    {children}
    <span className="cb-caption2 cb-mono cb-secondary">{label}</span>
  </div>
);

export const Grazing = () => (
  <div style={{ display: "flex", gap: 24, alignItems: "flex-end" }}>
    <Cell label="cow">
      <AnimalSprite animal="cow" scale={2} />
    </Cell>
    <Cell label="sheep">
      <AnimalSprite animal="sheep" scale={2} />
    </Cell>
    <Cell label="hen">
      <AnimalSprite animal="hen" scale={2} />
    </Cell>
  </div>
);

export const Walking = () => (
  <div style={{ display: "flex", gap: 24, alignItems: "flex-end" }}>
    <Cell label="cow walk sw">
      <AnimalSprite animal="cow" action="walk" facing="sw" scale={2} />
    </Cell>
    <Cell label="sheep walk ne">
      <AnimalSprite animal="sheep" action="walk" facing="ne" scale={2} />
    </Cell>
  </div>
);
