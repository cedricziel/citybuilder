import type { CSSProperties } from "react";
import { terrainSprites, type terrainSpritesKey } from "../../generated/terrain";

/** A terrain tile from `Resources/Terrain.atlas`: `grass`, `water`, `forest` ... */
export type TerrainArt = terrainSpritesKey;

export interface TerrainTileProps {
  terrain: TerrainArt;
  /** Scale over the 64x32 diamond. Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/** One 64x32 isometric terrain tile from the game's pixel art. */
export function TerrainTile({ terrain, scale = 1, style }: TerrainTileProps) {
  return (
    <img
      className="cb-pixel"
      src={terrainSprites[terrain]}
      alt={terrain}
      style={{ display: "block", zoom: scale, ...style }}
    />
  );
}
