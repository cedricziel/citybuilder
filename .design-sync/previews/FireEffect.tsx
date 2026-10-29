import { FireEffect, type BuildingArt } from "@citybuilder/ui";

const Cell = ({ art, night, animate }: { art: BuildingArt; night?: boolean; animate?: boolean }) => (
  <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
    <FireEffect building={art} night={night} animate={animate} />
    <span className="cb-caption2 cb-mono cb-secondary">{art}</span>
  </div>
);

const Row = ({ list, night, animate }: { list: BuildingArt[]; night?: boolean; animate?: boolean }) => (
  <div style={{ display: "flex", flexWrap: "wrap", alignItems: "flex-end", gap: 24, maxWidth: 820, paddingTop: 72 }}>
    {list.map((art) => (
      <Cell key={art} art={art} night={night} animate={animate} />
    ))}
  </div>
);

/** The flames grow with the footprint: a fire watch, a house, a workshop, a warehouse. */
export const Burning = () => <Row list={["fire-watch", "house", "sawmill", "warehouse"]} />;

export const Still = () => <Row list={["house", "bakery"]} animate={false} />;

export const Night = () => (
  <div className="cb-theme-dark" style={{ background: "#1b2440", padding: 16, borderRadius: 8 }}>
    <Row list={["house", "house-tier2"]} night />
  </div>
);
