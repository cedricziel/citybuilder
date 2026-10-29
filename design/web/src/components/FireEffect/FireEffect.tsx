import { useEffect, useState, type CSSProperties } from "react";
import { buildingSprites } from "../../generated/buildings";
import { buildingFootprint, type BuildingArt } from "../BuildingSprite/BuildingSprite";
import { AnimatedSprite } from "../AnimatedSprite/AnimatedSprite";
import "./FireEffect.css";

/** How far the soot darkens a burning building, as the game's colour blend toward black. */
export const fireSoot = 0.35;

/** The flames' scale for a footprint, as the game's `FireEffect.scale(for:)`: 0.75 (1×1) to 1.35 (3×3). */
export function fireScale(building: BuildingArt): number {
  const [w, h] = buildingFootprint(building);
  return 0.45 + 0.3 * Math.max(w, h);
}

/** The height of the image's topmost opaque row, as a fraction from its bottom (1 until measured). */
function useContentTop(src: string): number {
  const [top, setTop] = useState(1);
  useEffect(() => {
    const image = new Image();
    image.onload = () => {
      const canvas = document.createElement("canvas");
      canvas.width = image.width;
      canvas.height = image.height;
      const context = canvas.getContext("2d");
      if (!context) return;
      context.drawImage(image, 0, 0);
      const alpha = context.getImageData(0, 0, image.width, image.height).data;
      for (let row = 0; row < image.height; row++) {
        for (let column = 0; column < image.width; column++) {
          if (alpha[(row * image.width + column) * 4 + 3] > 32) {
            setTop((image.height - row) / image.height);
            return;
          }
        }
      }
    };
    image.src = src;
  }, [src]);
  return top;
}

export interface FireEffectProps {
  /** The burning building, named as in `BuildingSprite`. */
  building: BuildingArt;
  /** Flicker the flames (three frames at 0.14 s) and let the smoke rise. Still under reduced motion. Default true. */
  animate?: boolean;
  /** Draw it at night: the flames and glow light themselves, so only the building darkens. */
  night?: boolean;
  /** Scale over the art's @1x points. Default 1. */
  scale?: number;
  style?: CSSProperties;
}

/**
 * A building on fire, as the game draws it: the building darkened with soot, a cluster of self-lit
 * flame tongues on its roof (`effect-fire`) over a warm glow, and a dark smoke column leaning with
 * the wind. A fire watch's watchman puts it out; left alone it burns down to ruins.
 */
export function FireEffect({ building, animate = true, night = false, scale = 1, style }: FireEffectProps) {
  const src = buildingSprites[building];
  const top = useContentTop(src);
  const flames = fireScale(building);
  // The cluster's base sits 14 pt under the sprite's opaque top, as in the game.
  const roof = `calc(${top * 100}% - ${14 * flames}px)`;
  return (
    <span
      className={animate ? "cb-fire" : "cb-fire cb-fire--still"}
      style={{ zoom: scale, ...style }}
      role="img"
      aria-label={`${building.replace(/-/g, " ")} on fire`}
    >
      <img className="cb-pixel cb-fire__building" src={src} alt="" style={{ filter: `brightness(${(1 - fireSoot) * (night ? 0.6 : 1)})` }} />
      <span className="cb-fire__roof" style={{ bottom: roof }}>
        <span className="cb-fire__smoke" style={{ ["--cb-fire-scale" as string]: flames }}>
          <i />
          <i />
          <i />
          <i />
        </span>
        <span className="cb-fire__glow" style={{ width: 90 * flames, height: 70 * flames, bottom: -23 * flames }} />
        <AnimatedSprite cycle="effect-fire" timePerFrame={0.14} animate={animate} scale={flames} alt="" style={{ marginBottom: -8 }} />
      </span>
    </span>
  );
}
