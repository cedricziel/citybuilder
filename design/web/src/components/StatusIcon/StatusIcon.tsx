import type { CSSProperties } from "react";
import { statusSprites } from "../../generated/status";
import { goodName, type Good } from "../GoodIcon/GoodIcon";
import "./StatusIcon.css";

/**
 * An issue drawn as a white pictogram on a red disc: something blocks the building, it burns, or it is
 * ruins to clear. `blight` and `fever` sit on the cream disc with a pip: a blighted field (amber
 * pause) and a house fever holds back (red "!").
 */
export type StatusPictogram = "no-road" | "no-route" | "no-trees" | "no-room-to-plant" | "burning" | "ruins" | "blight" | "fever";

/**
 * What a status icon shows: a pictogram, or a good with a pip. `short` (red "!") is a missing input
 * or a house's unmet need; `stuck` (amber pause) is output with nowhere to go or a producer resting.
 */
export type StatusIssue = StatusPictogram | { good: Good; state: "short" | "stuck" };

/** The disc's diameter at zoom 1, per platform, in points. */
export const statusIconSizes = { touch: 22, mac: 20, tv: 30 } as const;

const pictogramLabels: Record<StatusPictogram, string> = {
  "no-road": "No road",
  "no-route": "No route to storage",
  "no-trees": "No trees in reach",
  "no-room-to-plant": "No room to plant",
  burning: "On fire",
  ruins: "Ruins: clear them",
  blight: "Blighted field",
  fever: "Fever",
};

/** "Short of bread", "Output stuck: planks", "No road". */
export function statusLabel(issue: StatusIssue): string {
  if (typeof issue === "string") return pictogramLabels[issue];
  const good = goodName(issue.good).toLowerCase();
  return issue.state === "short" ? `Short of ${good}` : `Output stuck: ${good}`;
}

export interface StatusIconProps {
  issue: StatusIssue;
  /** Platform size of the disc, or a disc diameter in px. */
  size?: keyof typeof statusIconSizes | number;
  /** The camera zoom; the icon follows clamp(zoom, 0.75, 1.25) of its size, so it shrinks less than the world. */
  zoom?: number;
  /** The 2 pt, 1.8 s bob. Always still when the viewer prefers reduced motion. */
  bob?: boolean;
  style?: CSSProperties;
}

/**
 * The icon that floats over a building while something is wrong, as the game draws it
 * (`status-*` in the Kit atlas). Shown only while there is a problem; one per building.
 */
export function StatusIcon({ issue, size = "mac", zoom = 1, bob = true, style }: StatusIconProps) {
  const name = typeof issue === "string" ? issue : `${issue.good}-${issue.state}`;
  const disc = (typeof size === "number" ? size : statusIconSizes[size]) * Math.min(Math.max(zoom, 0.75), 1.25);
  const cell = (disc * 28) / 24; // a 24-point disc on a 28-point cell
  return (
    <img
      className={bob ? "cb-status-icon cb-status-icon--bob" : "cb-status-icon"}
      src={statusSprites[name as keyof typeof statusSprites]}
      alt={statusLabel(issue)}
      title={statusLabel(issue)}
      width={cell}
      height={cell}
      style={style}
    />
  );
}
