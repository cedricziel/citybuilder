import type { CSSProperties } from "react";
import { buildingSprites, type buildingSpritesKey } from "../../generated/buildings";

/**
 * A building sprite, named as in `Resources/Kit.atlas` without the
 * `building-` prefix: `house`, `house-tier2`, `lumberjack-hut`, `port-n` ...
 */
export type BuildingArt = buildingSpritesKey;

export interface BuildingSpriteProps {
  building: BuildingArt;
  /** Scale factor over the art's native @1x points. A sprite can be wider than its footprint, to fit its shadow. Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/** The game's art for one building, as the IsoKit render the game shows. */
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
