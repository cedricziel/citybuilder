import type { CSSProperties } from "react";
import { AnimatedSprite, type Facing } from "../AnimatedSprite/AnimatedSprite";

/** What a carrier holds: `logs` (wood), `sack` (grain, flour), `crate` (tools, goods), `barrel` (beer, wine). */
export type CarrierLoad = "logs" | "sack" | "crate" | "barrel";

export interface CarrierSpriteProps {
  load: CarrierLoad;
  /** Default `se`, toward the camera. */
  facing?: Facing;
  /** Walk the 8-frame gait at 0.1 s a frame, as walkers do. Default true. */
  animate?: boolean;
  /** Scale over the 32x32 cell. Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/** A carrier hauling goods between buildings: a walker holding its load. */
export function CarrierSprite({ load, facing = "se", animate = true, scale, style }: CarrierSpriteProps) {
  return (
    <AnimatedSprite
      cycle={`carrier-${load}-${facing}`}
      timePerFrame={0.1}
      animate={animate}
      scale={scale}
      alt={`carrier with ${load} ${facing}`}
      style={style}
    />
  );
}
