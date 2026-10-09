import { BuildingSprite, type BuildingArt } from "@citybuilder/ui";

const Cell = ({ art }: { art: BuildingArt }) => (
  <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
    <BuildingSprite building={art} />
    <span className="cb-caption2 cb-mono cb-secondary">{art}</span>
  </div>
);

export const Housing = () => (
  <div style={{ display: "flex", alignItems: "flex-end", gap: 16 }}>
    <Cell art="house" />
    <Cell art="house-tier2" />
    <Cell art="house-tier3" />
  </div>
);

export const Production = () => (
  <div style={{ display: "flex", flexWrap: "wrap", alignItems: "flex-end", gap: 16, maxWidth: 600 }}>
    <Cell art="lumberjack-hut" />
    <Cell art="sawmill" />
    <Cell art="farm" />
    <Cell art="windmill" />
    <Cell art="bakery" />
    <Cell art="mine" />
  </div>
);

export const Civic = () => (
  <div style={{ display: "flex", alignItems: "flex-end", gap: 16 }}>
    <Cell art="town-center" />
    <Cell art="warehouse" />
    <Cell art="monument" />
  </div>
);
