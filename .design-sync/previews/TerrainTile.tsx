import { TerrainTile, type TerrainArt, type TerrainObjectArt } from "@citybuilder/ui";

const Label = ({ children }: { children: React.ReactNode }) => <span className="cb-caption2 cb-mono cb-secondary">{children}</span>;

const Row = ({ list }: { list: TerrainArt[] }) => (
  <div style={{ display: "flex", flexWrap: "wrap", gap: 16 }}>
    {list.map((terrain) => (
      <div key={terrain} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
        <TerrainTile terrain={terrain} scale={2} />
        <Label>{terrain}</Label>
      </div>
    ))}
  </div>
);

const Objects = ({ list, ground = "grass" }: { list: TerrainObjectArt[]; ground?: TerrainArt }) => (
  <div style={{ display: "flex", flexWrap: "wrap", alignItems: "flex-end", gap: 8 }}>
    {list.map((object) => (
      <div key={object} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
        <TerrainTile terrain={ground} object={object} />
        <Label>{object}</Label>
      </div>
    ))}
  </div>
);

export const Ground = () => <Row list={["grass", "grass-v1", "grass-v2", "grass-v3", "beach", "water"]} />;

export const Seasons = () => <Row list={["grass", "grass-autumn", "grass-winter"]} />;

export const Shores = () => <Row list={["grass-beach-t3", "grass-beach-t6", "grass-beach-t12", "beach-water-t3", "beach-water-t9", "beach-water-t14"]} />;

export const Trees = () => <Objects list={["forest-sparse", "forest-medium", "forest-dense", "forest-dense-autumn", "forest-dense-winter"]} />;

export const Rocks = () => (
  <Objects list={["mountain-sparse", "mountain-medium", "mountain-dense", "mountain-peak", "mountain-peak-winter"]} />
);
