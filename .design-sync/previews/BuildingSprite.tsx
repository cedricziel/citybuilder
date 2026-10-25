import { BuildingSprite, buildingFootprint, type BuildingArt } from "@citybuilder/ui";

const Cell = ({ art, night }: { art: BuildingArt; night?: boolean }) => {
  const [w, h] = buildingFootprint(art);
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
      <BuildingSprite building={art} night={night} />
      <span className="cb-caption2 cb-mono cb-secondary">
        {art} · {w}×{h}
      </span>
    </div>
  );
};

const Row = ({ list, night }: { list: BuildingArt[]; night?: boolean }) => (
  <div style={{ display: "flex", flexWrap: "wrap", alignItems: "flex-end", gap: 16, maxWidth: 820 }}>
    {list.map((art) => (
      <Cell key={art} art={art} night={night} />
    ))}
  </div>
);

export const Housing = () => <Row list={["house", "house-tier2", "house-tier3"]} />;

export const Production = () => (
  <Row list={["lumberjack-hut", "forester", "sawmill", "farm", "grain-farm", "windmill", "quern-house", "bakery", "mine", "charcoal-burner", "smelter", "toolsmith"]} />
);

export const Culture = () => (
  <Row list={["hop-garden", "brewery", "mead-hall", "vineyard", "winery", "forum", "tea-garden", "tea-house", "temple-garden", "coffee-grove", "roastery", "caravanserai"]} />
);

export const Civic = () => <Row list={["town-center", "warehouse", "library", "guild-hall", "gallery", "monument"]} />;

export const Waterfront = () => <Row list={["port-n", "port-e", "shipyard-n", "shipyard-e"]} />;

export const Industry = () => <Row list={["steam-engine", "power-plant"]} />;

export const Night = () => (
  <div className="cb-theme-dark" style={{ background: "#1b2440", padding: 16, borderRadius: 8 }}>
    <Row list={["house", "house-tier2", "house-tier3", "bakery", "windmill", "toolsmith"]} night />
  </div>
);
