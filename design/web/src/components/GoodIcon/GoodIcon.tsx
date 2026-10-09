import type { CSSProperties } from "react";
import { goodSprites, type goodSpritesKey } from "../../generated/goods";

/** A tradeable good, named as in the game's `Good` enum (kebab-case). */
export type Good = goodSpritesKey;

/** Every good, in the app's `Good.allCases` order where known. */
export const goods: Good[] = [
  "wood",
  "planks",
  "food",
  "grain",
  "flour",
  "bread",
  "ore",
  "charcoal",
  "iron",
  "tools",
  "hops",
  "beer",
  "grapes",
  "wine",
  "tea-leaves",
  "tea",
  "coffee-cherries",
  "coffee",
];

/** "Coffee cherries" from `coffee-cherries`. */
export function goodName(good: Good): string {
  const words = good.replace(/-/g, " ");
  return words.charAt(0).toUpperCase() + words.slice(1);
}

export interface GoodIconProps {
  good: Good;
  /** Rendered size in px. The art is 24x24 pixel art; the HUD draws it at 16, cost chips at 14. */
  size?: number;
  style?: CSSProperties;
}

/** The game's pixel-art icon for a good, scaled without smoothing. */
export function GoodIcon({ good, size = 16, style }: GoodIconProps) {
  return (
    <img
      className="cb-pixel"
      src={goodSprites[good]}
      alt={goodName(good)}
      width={size}
      height={size}
      style={{ display: "inline-block", flex: "none", ...style }}
    />
  );
}
