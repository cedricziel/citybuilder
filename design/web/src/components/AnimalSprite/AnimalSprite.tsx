import type { CSSProperties } from "react";
import { AnimatedSprite, type Facing } from "../AnimatedSprite/AnimatedSprite";

export type Animal = "cow" | "sheep" | "hen";

export interface AnimalSpriteProps {
  animal: Animal;
  /** Cows and sheep `walk` (8 frames, 0.12 s) or `graze` (4 frames, 0.3 s); hens always peck (4 frames, 0.15 s). Default `graze`. */
  action?: "walk" | "graze";
  /** Default `se`. */
  facing?: Facing;
  /** Play the cycle. Default true. */
  animate?: boolean;
  /** Scale over the art's points (cow 52x44, sheep 34x26, hen 18x14). Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/** A farm animal round its farm or house: a cow, a sheep or a hen. */
export function AnimalSprite({ animal, action = "graze", facing = "se", animate = true, scale, style }: AnimalSpriteProps) {
  if (animal === "hen") {
    return <AnimatedSprite cycle={`animal-hen-${facing}`} timePerFrame={0.15} animate={animate} scale={scale} alt="hen" style={style} />;
  }
  return (
    <AnimatedSprite
      cycle={`animal-${animal}-${action}-${facing}`}
      timePerFrame={action === "walk" ? 0.12 : 0.3}
      animate={animate}
      scale={scale}
      alt={`${animal} ${action === "walk" ? "walking" : "grazing"}`}
      style={style}
    />
  );
}
