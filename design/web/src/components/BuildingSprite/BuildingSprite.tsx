import type { CSSProperties } from "react";
import { buildingSprites, type buildingSpritesKey } from "../../generated/buildings";

/**
 * A building sprite, named as in `Resources/Buildings.atlas` without the
 * `building-` prefix: `house`, `house-tier2`, `lumberjack-hut`, `port-n` ...
 */
export type BuildingArt = buildingSpritesKey;

export interface BuildingSpriteProps {
  building: BuildingArt;
  /** Scale factor over the art's native pixels (most buildings are 128 wide). Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/** The game's isometric pixel art for one building, scaled without smoothing. */
export function BuildingSprite({ building, scale = 1, style }: BuildingSpriteProps) {
  return (
    <img
      className="cb-pixel"
      src={buildingSprites[building]}
      alt={building.replace(/-/g, " ")}
      style={{ display: "block", zoom: scale, ...style }}
    />
  );
}
