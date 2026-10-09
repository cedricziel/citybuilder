import type { CSSProperties, ReactNode } from "react";
import { buildingSprites, type buildingSpritesKey } from "../../generated/buildings";
import { buildingSizes } from "../../generated/buildingSizes";
import { terrainSprites, type terrainSpritesKey } from "../../generated/terrain";
import "./WorldBackdrop.css";

export interface PlacedBuilding {
  /** Sprite key, e.g. `house`, `warehouse`, `road`, `lumberjack-hut`. */
  art: buildingSpritesKey;
  /** Anchor tile (the footprint's top corner) in map coordinates. */
  x: number;
  y: number;
  /** Draw as a translucent ghost (a pending placement). */
  ghost?: boolean;
}

export interface WorldBackdropProps {
  /** Viewport width in px. Default 100% of the parent. */
  width?: number | string;
  /** Viewport height in px. Default 100% of the parent. */
  height?: number | string;
  /**
   * The map as rows of characters: `~` water, `.` beach, `,` grass,
   * `T` forest, `^` mountain. Default: a small island. Outside the map is sea.
   */
  map?: string[];
  /** Buildings and road tiles on the map. Default: a small medieval town. */
  buildings?: PlacedBuilding[];
  /** Pixel zoom (the app's camera zoom). Default 1.5. */
  zoom?: number;
  /** Tile at the viewport center. Default: the map center. */
  center?: { x: number; y: number };
  /** Seasonal grass and forest. Default `summer`. */
  season?: "summer" | "autumn" | "winter";
  /** Highlight one tile with the selection diamond. */
  selected?: { x: number; y: number };
  /** HUD and overlays drawn above the map. */
  children?: ReactNode;
  style?: CSSProperties;
}

export const defaultIsland: string[] = [
  "~~~~~~~~~~~~~~~~",
  "~~~~~....~~~~~~~",
  "~~~~..,,,,..~~~~",
  "~~~.,,,TT,,,.~~~",
  "~~.,,,TTT,,,,.~~",
  "~~.,,,,T,,,,^.~~",
  "~.,,,,,,,,,,^^.~",
  "~.,,,,,,,,,,,^.~",
  "~.,,,,,,,,,,,,.~",
  "~~.,,,,,,,,,TT.~",
  "~~.,,,,,,,,TTT.~",
  "~~~.,,,,,,,,T.~~",
  "~~~~..,,,,,..~~~",
  "~~~~~~.....~~~~~",
  "~~~~~~~~~~~~~~~~",
  "~~~~~~~~~~~~~~~~",
];

export const defaultTown: PlacedBuilding[] = [
  { art: "town-center", x: 6, y: 6 },
  { art: "road", x: 5, y: 6 },
  { art: "road", x: 5, y: 7 },
  { art: "road", x: 5, y: 8 },
  { art: "road", x: 5, y: 9 },
  { art: "road", x: 6, y: 9 },
  { art: "road", x: 7, y: 9 },
  { art: "road", x: 8, y: 9 },
  { art: "road", x: 9, y: 9 },
  { art: "road", x: 9, y: 8 },
  { art: "road", x: 9, y: 7 },
  { art: "road", x: 9, y: 6 },
  { art: "house", x: 3, y: 6 },
  { art: "house-tier2", x: 3, y: 8 },
  { art: "house", x: 6, y: 10 },
  { art: "house-tier2", x: 8, y: 10 },
  { art: "warehouse", x: 10, y: 6 },
  { art: "lumberjack-hut", x: 7, y: 3 },
  { art: "farm", x: 10, y: 9 },
  { art: "windmill", x: 3, y: 10 },
];

const tileArt: Record<string, terrainSpritesKey> = {
  "~": "water",
  ".": "beach",
  ",": "grass",
  T: "forest",
  "^": "mountain",
};

function seasonal(art: terrainSpritesKey, season: WorldBackdropProps["season"]): terrainSpritesKey {
  if (season === "summer" || !season) return art;
  if (art === "grass") return season === "autumn" ? "grass-autumn" : "grass-winter";
  if (art === "forest") return season === "autumn" ? "forest-autumn" : "forest-winter";
  return art;
}

const HALF_W = 32;
const HALF_H = 16;
const PAD = 14;

/**
 * The isometric world map from the game's own pixel art: terrain tiles,
 * roads and buildings, as the SpriteKit world view draws it. Use it as the
 * backdrop of any in-game screen; HUD pieces go in `children`.
 */
export function WorldBackdrop({
  width = "100%",
  height = "100%",
  map = defaultIsland,
  buildings = defaultTown,
  zoom = 1.5,
  center,
  season = "summer",
  selected,
  children,
  style,
}: WorldBackdropProps) {
  const rows = map.length;
  const cols = Math.max(...map.map((row) => row.length));
  const cx = center?.x ?? (cols - 1) / 2;
  const cy = center?.y ?? (rows - 1) / 2;
  const at = (x: number, y: number) => ({
    left: (x - cx - (y - cy)) * HALF_W,
    top: (x - cx + (y - cy)) * HALF_H,
  });

  const tiles: ReactNode[] = [];
  for (let sum = -2 * PAD; sum <= rows + cols + 2 * PAD; sum++) {
    for (let x = -PAD; x < cols + PAD; x++) {
      const y = sum - x;
      if (y < -PAD || y >= rows + PAD) continue;
      const ch = map[y]?.[x] ?? "~";
      const art = seasonal(tileArt[ch] ?? "water", season);
      const pos = at(x, y);
      tiles.push(
        <img key={`${x},${y}`} className="cb-world__tile cb-pixel" src={terrainSprites[art]} alt="" style={{ left: pos.left - HALF_W, top: pos.top - HALF_H }} />,
      );
    }
  }

  const sorted = [...buildings].sort((a, b) => depth(a) - depth(b));
  const sprites = sorted.map((building, index) => {
    const [w, h] = buildingSizes[building.art];
    const f = Math.max(1, Math.round(w / 64));
    const bottom = at(building.x + f - 1, building.y + f - 1);
    const centerX = (at(building.x, building.y + f - 1).left + at(building.x + f - 1, building.y).left) / 2;
    return (
      <img
        key={`${building.art}-${building.x}-${building.y}-${index}`}
        className={`cb-world__building cb-pixel ${building.ghost ? "cb-world__building--ghost" : ""}`}
        src={buildingSprites[building.art]}
        alt={building.art}
        style={{ left: centerX - w / 2, top: bottom.top + HALF_H - h }}
      />
    );
  });

  const selection = selected ? at(selected.x, selected.y) : null;

  return (
    <div className="cb-world" style={{ width, height, ...style }}>
      <div className="cb-world__plane" style={{ transform: `scale(${zoom})` }}>
        {tiles}
        {selection ? <div className="cb-world__selection" style={{ left: selection.left - HALF_W, top: selection.top - HALF_H }} /> : null}
        {sprites}
      </div>
      {children ? <div className="cb-world__overlay">{children}</div> : null}
    </div>
  );
}

function depth(building: PlacedBuilding): number {
  const [w] = buildingSizes[building.art];
  const f = Math.max(1, Math.round(w / 64));
  return building.x + building.y + 2 * (f - 1);
}
