import type { CSSProperties } from "react";
import { terrainSprites, type terrainSpritesKey } from "../../generated/terrain";
import { terrainObjectSprites, type terrainObjectSpritesKey } from "../../generated/terrainObjects";

/**
 * A ground tile from `Resources/Kit.atlas` without the `terrain-` prefix:
 * `grass`, `grass-v2`, `grass-autumn`, `beach`, `water`, and the shore
 * transitions `grass-beach-t3`, `beach-water-t12` (corner mask N=1, E=2, S=4, W=8).
 */
export type TerrainArt = terrainSpritesKey;

/**
 * A tree clump or rock outcrop that stands on grass:
 * `forest-<sparse|medium|dense>[-autumn|-winter][-v1..3]` and
 * `mountain-<sparse|medium|dense|peak>[-winter][-v1..3]`.
 */
export type TerrainObjectArt = terrainObjectSpritesKey;

export interface TerrainTileProps {
  terrain: TerrainArt;
  /** A tree clump or rock outcrop drawn over the tile, as the world view stands it on forest and mountain. */
  object?: TerrainObjectArt;
  /** Scale over the 64x32 diamond. Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/** The object cell is 144 x 132 points with the tile centre 56 from its left and 112 from its top. */
const OBJECT_CELL = { width: 144, height: 132, centerX: 56, centerY: 112 };

/**
 * One 64x32 isometric ground tile from the game's art, optionally with the
 * tree clump or rock outcrop that stands on it.
 */
export function TerrainTile({ terrain, object, scale = 1, style }: TerrainTileProps) {
  const tile = <img className="cb-pixel" src={terrainSprites[terrain]} alt={terrain} style={{ display: "block" }} />;
  if (!object) {
    return <span style={{ display: "block", width: "max-content", zoom: scale, ...style }}>{tile}</span>;
  }
  // Leave room above and beside the tile for the object's cell.
  const left = OBJECT_CELL.centerX - 32;
  const top = OBJECT_CELL.centerY - 16;
  return (
    <span
      style={{
        position: "relative",
        display: "block",
        width: OBJECT_CELL.width,
        height: OBJECT_CELL.height,
        zoom: scale,
        ...style,
      }}
    >
      <span style={{ position: "absolute", left, top }}>{tile}</span>
      <img className="cb-pixel" src={terrainObjectSprites[object]} alt={object} style={{ position: "absolute", left: 0, top: 0, display: "block" }} />
    </span>
  );
}
