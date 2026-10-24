import type { CSSProperties } from "react";
import { AnimatedSprite } from "../AnimatedSprite/AnimatedSprite";

/** A ship's heading, in eight directions. */
export type ShipHeading = "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw";

export interface ShipSpriteProps {
  /** Default `se`. */
  heading?: ShipHeading;
  /** Sailing: the hull rocks between its two frames. Moored ships hold frame 0. Default true. */
  sailing?: boolean;
  /** Scale over the 64x72 cell. Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/** A trade ship from the shipyard, sailing its route between ports. */
export function ShipSprite({ heading = "se", sailing = true, scale, style }: ShipSpriteProps) {
  return <AnimatedSprite cycle={`ship-${heading}`} timePerFrame={0.5} animate={sailing} scale={scale} alt={`ship heading ${heading}`} style={style} />;
}
