import type { CSSProperties } from "react";
import { buildingSprites, type buildingSpritesKey } from "../../generated/buildings";
import { buildingFootprints } from "../../generated/buildingFootprints";
import { buildingLights } from "../../generated/lights";
import "./BuildingSprite.css";

/**
 * A building sprite, named as in `Resources/Kit.atlas` without the
 * `building-` prefix: `house`, `house-tier2`, `lumberjack-hut`, `port-n` ...
 */
export type BuildingArt = buildingSpritesKey;

/** Every building sprite the bundle carries, in atlas order. */
export const buildingArts = Object.keys(buildingSprites) as BuildingArt[];

/** The footprint in tiles, [columns along x, rows along y]: `town-center` is 3×3, `house` 2×2. */
export function buildingFootprint(building: BuildingArt): [number, number] {
  return buildingFootprints[building];
}

/** Whether the building has night-lights art (houses and the fired workshops). */
export function hasNightLights(building: BuildingArt): boolean {
  return building in buildingLights;
}

export interface BuildingSpriteProps {
  building: BuildingArt;
  /** Scale factor over the art's native @1x points. A sprite can be wider than its footprint, to fit its shadow. Default 1. */
  scale?: number;
  /**
   * Draw it at night: the scene's blue night tint over the sprite, and its
   * lit windows added on top where the building has lights art.
   */
  night?: boolean;
  style?: CSSProperties;
}

/** The game's art for one building, as the IsoKit render the game shows. */
export function BuildingSprite({ building, scale = 1, night = false, style }: BuildingSpriteProps) {
  const src = buildingSprites[building];
  const alt = building.replace(/-/g, " ");
  if (!night) {
    return <img className="cb-pixel" src={src} alt={alt} style={{ display: "block", zoom: scale, ...style }} />;
  }
  const lights = buildingLights[building];
  return (
    <span className="cb-building-sprite--night" style={{ zoom: scale, ...style }}>
      <img className="cb-pixel" src={src} alt={alt} />
      <span className="cb-building-sprite__tint" style={{ maskImage: `url(${src})`, WebkitMaskImage: `url(${src})` }} />
      {lights ? <img className="cb-pixel cb-building-sprite__lights" src={lights} alt="" /> : null}
    </span>
  );
}
