import type { CSSProperties } from "react";
import { AnimatedSprite, type Facing } from "../AnimatedSprite/AnimatedSprite";

export interface WalkerSpriteProps {
  /**
   * `worker` (the default resident and labourer), `woman`, or `watchman`: a fire watch's watchman
   * with his leather bucket, walking to a fire. Default `worker`.
   */
  look?: "worker" | "woman" | "watchman";
  /** Default `se`, toward the camera. */
  facing?: Facing;
  /** Walk the 8-frame gait at 0.1 s a frame. Off, the figure stands (frame 0). Default true. */
  animate?: boolean;
  /** Scale over the 32x32 cell. Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/**
 * A resident walking the streets: a 32x32 IsoKit figure with an 8-frame
 * gait. In the world its feet stand 12 points from the cell's left and 5
 * from its bottom.
 */
export function WalkerSprite({ look = "worker", facing = "se", animate = true, scale, style }: WalkerSpriteProps) {
  const cycle = look === "worker" ? (`walker-${facing}` as const) : (`walker-${look}-${facing}` as const);
  return <AnimatedSprite cycle={cycle} timePerFrame={0.1} animate={animate} scale={scale} alt={`${look} walking ${facing}`} style={style} />;
}
