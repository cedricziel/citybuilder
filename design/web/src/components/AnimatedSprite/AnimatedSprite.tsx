import { useEffect, useState, type CSSProperties } from "react";
import { unitSprites, unitSizes, type unitSpritesKey } from "../../generated/units";

/** A figure's or ship's facing, as the game names it. */
export type Facing = "ne" | "nw" | "se" | "sw";

export interface AnimatedSpriteProps {
  /** The cycle's key in the generated unit sprites, e.g. `walker-ne`, `animal-cow-graze-sw`, `ship-e`. */
  cycle: unitSpritesKey;
  /** Seconds per frame, as the game's `SpriteAnimation` entry. */
  timePerFrame: number;
  /** Play the cycle. Off, the sprite holds `frame`. Default true. */
  animate?: boolean;
  /** The frame shown while not animating. Default 0 (a figure's standing pose). */
  frame?: number;
  /** Scale over the art's @1x points. Default 1. */
  scale?: number;
  alt?: string;
  style?: CSSProperties;
}

/** Steps through a cycle's frames on a timer; holds the first under reduced motion. */
function useFrame(count: number, timePerFrame: number, animate: boolean, start: number): number {
  const [frame, setFrame] = useState(start % count);
  useEffect(() => {
    const reduced = typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
    if (!animate || reduced || count < 2) {
      setFrame(start % count);
      return;
    }
    const timer = window.setInterval(() => setFrame((current) => (current + 1) % count), timePerFrame * 1000);
    return () => window.clearInterval(timer);
  }, [count, timePerFrame, animate, start]);
  return frame;
}

/** One animated sprite from the game's figure and ship art, drawn without smoothing. */
export function AnimatedSprite({ cycle, timePerFrame, animate = true, frame = 0, scale = 1, alt = "", style }: AnimatedSpriteProps) {
  const frames = unitSprites[cycle];
  const shown = useFrame(frames.length, timePerFrame, animate, frame);
  const [width, height] = unitSizes[cycle];
  return (
    <img
      className="cb-pixel"
      src={frames[shown]}
      alt={alt}
      width={width}
      height={height}
      style={{ display: "block", zoom: scale, ...style }}
    />
  );
}
