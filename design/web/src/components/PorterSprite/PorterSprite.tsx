import type { CSSProperties } from "react";
import { AnimatedSprite, type Facing } from "../AnimatedSprite/AnimatedSprite";

export interface PorterSpriteProps {
  /** The walk back to the market, baskets empty. Default false: baskets filled on the way to a house. */
  empty?: boolean;
  /** Default `se`, toward the camera. */
  facing?: Facing;
  /** Walk the 8-frame gait at 0.1 s a frame, as walkers do. Default true. */
  animate?: boolean;
  /** Scale over the 32x32 cell. Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/** A market porter carrying house goods on a shoulder yoke, from the town center or a marketplace to a house. */
export function PorterSprite({ empty = false, facing = "se", animate = true, scale, style }: PorterSpriteProps) {
  return (
    <AnimatedSprite
      cycle={`porter${empty ? "-empty" : ""}-${facing}`}
      timePerFrame={0.1}
      animate={animate}
      scale={scale}
      alt={`market porter${empty ? " returning" : ""} ${facing}`}
      style={style}
    />
  );
}
