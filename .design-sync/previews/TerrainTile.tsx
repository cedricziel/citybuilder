import { TerrainTile, type TerrainArt } from "@citybuilder/ui";

const tiles: TerrainArt[] = ["grass", "forest", "mountain", "beach", "water"];
const seasons: TerrainArt[] = ["grass", "grass-autumn", "grass-winter", "forest", "forest-autumn", "forest-winter"];

const Row = ({ list }: { list: TerrainArt[] }) => (
  <div style={{ display: "flex", gap: 16 }}>
    {list.map((terrain) => (
      <div key={terrain} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
        <TerrainTile terrain={terrain} scale={2} />
        <span className="cb-caption2 cb-mono cb-secondary">{terrain}</span>
      </div>
    ))}
  </div>
);

export const Kinds = () => <Row list={tiles} />;
export const Seasons = () => <Row list={seasons} />;
