import { TileMenu, WorldBackdrop } from "@citybuilder/ui";

export const EmptyTile = () => (
  <WorldBackdrop width={400} height={520} zoom={2}>
    <div style={{ position: "absolute", inset: 0, background: "var(--cb-scrim)", display: "flex", alignItems: "flex-end", justifyContent: "center", padding: 8 }}>
      <TileMenu
        width={384}
        items={[
          { title: "House — $120" },
          { title: "Road — $5" },
          { title: "Lumberjack — $80" },
          { title: "Farm — $90" },
          { title: "Brewery — Needs research", disabled: true },
          { title: "Warehouse — Costs $300", disabled: true },
        ]}
      />
    </div>
  </WorldBackdrop>
);

export const OccupiedTile = () => (
  <WorldBackdrop width={400} height={330} zoom={2}>
    <div style={{ position: "absolute", inset: 0, background: "var(--cb-scrim)", display: "flex", alignItems: "flex-end", justifyContent: "center", padding: 8 }}>
      <TileMenu
        width={384}
        items={[
          { title: "House — Tile is occupied", disabled: true },
          { title: "Road — Tile is occupied", disabled: true },
          { title: "Demolish", destructive: true },
        ]}
      />
    </div>
  </WorldBackdrop>
);
