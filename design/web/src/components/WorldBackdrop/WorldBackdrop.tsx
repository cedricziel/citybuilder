import type { CSSProperties, ReactNode } from "react";
import { buildingSprites, type buildingSpritesKey } from "../../generated/buildings";
import { buildingFootprints } from "../../generated/buildingFootprints";
import { buildingSizes } from "../../generated/buildingSizes";
import { buildingLights } from "../../generated/lights";
import { terrainSprites } from "../../generated/terrain";
import { terrainObjectSprites } from "../../generated/terrainObjects";
import { unitSprites, type unitSpritesKey } from "../../generated/units";
import type { Facing } from "../AnimatedSprite/AnimatedSprite";
import { groundSprite, terrainObjects, terrainOf } from "./terrain";
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

/**
 * A figure, animal or ship standing on the map, drawn at its first frame
 * (use `WalkerSprite`, `CarrierSprite`, `AnimalSprite` or `ShipSprite` for
 * the animated art on its own). `x` and `y` are map tiles; fractions place
 * it between tile centres.
 */
export type PlacedUnit = { x: number; y: number } & (
  | { unit: "walker" | "woman"; facing?: Facing }
  | { unit: "carrier"; load: "logs" | "sack" | "crate" | "barrel"; facing?: Facing }
  | { unit: "cow" | "sheep"; action?: "walk" | "graze"; facing?: Facing }
  | { unit: "hen"; facing?: Facing }
  | { unit: "ship"; heading?: "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw" }
);

/** A unit's cycle, and where its feet (or a ship's waterline) sit in its cell, from the top left. */
function unitArt(unit: PlacedUnit): { cycle: unitSpritesKey; footX: number; footY: number } {
  const facing = "facing" in unit && unit.facing ? unit.facing : "se";
  switch (unit.unit) {
    case "walker":
    case "woman": {
      const cycle: unitSpritesKey = unit.unit === "woman" ? `walker-woman-${facing}` : `walker-${facing}`;
      return { cycle, footX: 12, footY: 32 - 5 };
    }
    case "carrier":
      return { cycle: `carrier-${unit.load}-${facing}`, footX: 12, footY: 32 - 5 };
    case "cow":
      return { cycle: `animal-cow-${unit.action ?? "graze"}-${facing}`, footX: 21, footY: 44 - 11 };
    case "sheep":
      return { cycle: `animal-sheep-${unit.action ?? "graze"}-${facing}`, footX: 14, footY: 26 - 7 };
    case "hen":
      return { cycle: `animal-hen-${facing}`, footX: 8, footY: 14 - 4 };
    case "ship":
      // The ship node anchors at (0.5, 0.3) from its bottom left.
      return { cycle: `ship-${unit.heading ?? "se"}`, footX: 32, footY: 72 * 0.7 };
  }
}

export interface TileCoordinate {
  x: number;
  y: number;
}

/**
 * What a building reaches, as the world view draws it while placing or
 * selecting: a gold outline over a dark under-stroke round `tiles`, with a
 * faint gold tint, and a stronger tint on `planted` (the open grass a
 * forester would plant). Trees and rock in reach are brightened.
 */
export interface AreaOfEffect {
  tiles: TileCoordinate[];
  planted?: TileCoordinate[];
}

export interface WorldBackdropProps {
  /** Viewport width in px. Default 100% of the parent. */
  width?: number | string;
  /** Viewport height in px. Default 100% of the parent. */
  height?: number | string;
  /**
   * The map as rows of characters: `~` water, `.` beach, `,` grass,
   * `T` forest, `^` mountain. Default: a small island. Outside the map is sea.
   * Forest and mountain are grass with tree clumps and rock outcrops on it.
   */
  map?: string[];
  /** Buildings and road tiles on the map. Default: a small medieval town. */
  buildings?: PlacedBuilding[];
  /** Pixel zoom (the app's camera zoom). Default 1.5. */
  zoom?: number;
  /** Tile at the viewport center. Default: the map center. */
  center?: { x: number; y: number };
  /** Seasonal grass, trees and rock. Default `summer`. */
  season?: "summer" | "autumn" | "winter";
  /** Night: the blue night overlay over the world, with houses' and workshops' windows lit. */
  night?: boolean;
  /** Where `center` lands vertically, as a fraction of the viewport height. Default 0.5. */
  focusY?: number;
  /** Highlight one tile with the selection diamond. */
  selected?: { x: number; y: number };
  /** An area of effect on the ground: the gold ring of #242. */
  area?: AreaOfEffect;
  /** Walkers, carriers, animals and ships on the map. */
  units?: PlacedUnit[];
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

const HALF_W = 32;
const HALF_H = 16;
const PAD = 14;
/** A terrain object's 144 x 132 cell has the tile centre 56 from its left and 112 from its top. */
const OBJECT_CENTER = { x: 56, y: 112 };

/**
 * The isometric world map from the game's own art: painterly ground with
 * its grass variants and shore transitions, tree clumps and rock outcrops,
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
  night = false,
  focusY = 0.5,
  selected,
  area,
  units = [],
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
  const terrainAt = (x: number, y: number) => terrainOf(map[y]?.[x]);

  const tiles: ReactNode[] = [];
  for (let sum = -2 * PAD; sum <= rows + cols + 2 * PAD; sum++) {
    for (let x = -PAD; x < cols + PAD; x++) {
      const y = sum - x;
      if (y < -PAD || y >= rows + PAD) continue;
      const art = groundSprite(x, y, terrainAt, season);
      const pos = at(x, y);
      tiles.push(
        <img key={`${x},${y}`} className="cb-world__tile cb-pixel" src={terrainSprites[art]} alt="" style={{ left: pos.left - HALF_W, top: pos.top - HALF_H }} />,
      );
    }
  }

  const occupied = new Set<string>();
  for (const building of buildings) {
    if (building.ghost) continue;
    const [w, h] = buildingFootprints[building.art];
    for (let dy = 0; dy < h; dy++) for (let dx = 0; dx < w; dx++) occupied.add(`${building.x + dx},${building.y + dy}`);
  }
  const inReach = new Set(area?.tiles.map(({ x, y }) => `${x},${y}`));

  // Objects sort like a 1 x 1 building on their tile, just behind a building at the same depth.
  const standing: { depth: number; node: ReactNode; lights?: ReactNode }[] = [];
  for (const object of terrainObjects(cols, rows, terrainAt, occupied, season)) {
    const pos = at(object.x, object.y);
    standing.push({
      depth: object.x + object.y - 0.01,
      node: (
        <img
          key={`object-${object.x}-${object.y}`}
          className={`cb-world__object cb-pixel ${inReach.has(`${object.x},${object.y}`) ? "cb-world__object--in-reach" : ""}`}
          src={terrainObjectSprites[object.art]}
          alt=""
          style={{ left: pos.left - OBJECT_CENTER.x, top: pos.top - OBJECT_CENTER.y }}
        />
      ),
    });
  }
  buildings.forEach((building, index) => {
    const [w, h] = buildingSizes[building.art];
    // The sprite is wider than its footprint where its shadow needs room, so place it by its footprint.
    const [fx, fy] = buildingFootprints[building.art];
    const bottom = at(building.x + fx - 1, building.y + fy - 1);
    const centerX = (at(building.x, building.y + fy - 1).left + at(building.x + fx - 1, building.y).left) / 2;
    const place = { left: centerX - w / 2, top: bottom.top + HALF_H - h };
    const key = `${building.art}-${building.x}-${building.y}-${index}`;
    const lit = night && !building.ghost ? buildingLights[building.art] : undefined;
    standing.push({
      depth: building.x + building.y + (fx - 1) + (fy - 1),
      node: (
        <img
          key={key}
          className={`cb-world__building cb-pixel ${building.ghost ? "cb-world__building--ghost" : ""}`}
          src={buildingSprites[building.art]}
          alt={building.art}
          style={place}
        />
      ),
      lights: lit ? <img key={`${key}-lights`} className="cb-world__lights cb-pixel" src={lit} alt="" style={place} /> : undefined,
    });
  });
  units.forEach((unit, index) => {
    const { cycle, footX, footY } = unitArt(unit);
    // A figure stands on the tile centre at (x, y); fractions interpolate between centres.
    const pos = { left: (unit.x - cx - (unit.y - cy)) * HALF_W, top: (unit.x - cx + (unit.y - cy)) * HALF_H };
    standing.push({
      depth: unit.x + unit.y + 0.5,
      node: (
        <img
          key={`unit-${index}`}
          className="cb-world__unit cb-pixel"
          src={unitSprites[cycle][0]}
          alt=""
          style={{ left: pos.left - footX, top: pos.top - footY }}
        />
      ),
    });
  });
  standing.sort((a, b) => a.depth - b.depth);

  const selection = selected ? at(selected.x, selected.y) : null;

  return (
    <div className="cb-world" style={{ width, height, ...style }}>
      <div className="cb-world__plane" style={{ top: `${focusY * 100}%`, transform: `scale(${zoom})` }}>
        {tiles}
        {area ? <AreaRing area={area} at={at} /> : null}
        {selection ? <div className="cb-world__selection" style={{ left: selection.left - HALF_W, top: selection.top - HALF_H }} /> : null}
        {standing.map((item) => item.node)}
        {night ? <div className="cb-world__night" /> : null}
        {standing.map((item) => item.lights)}
      </div>
      {children ? <div className="cb-world__overlay">{children}</div> : null}
    </div>
  );
}

/** The boundary of the area as tile edges with no neighbour inside it, plus the tinted tiles. */
function AreaRing({ area, at }: { area: AreaOfEffect; at: (x: number, y: number) => { left: number; top: number } }) {
  const inside = new Set(area.tiles.map(({ x, y }) => `${x},${y}`));
  // Vertex (vx, vy) is the top corner of tile (vx, vy).
  const vertex = (vx: number, vy: number) => {
    const p = at(vx, vy);
    return `${p.left},${p.top - HALF_H}`;
  };
  const diamond = ({ x, y }: TileCoordinate) => `${vertex(x, y)} ${vertex(x + 1, y)} ${vertex(x + 1, y + 1)} ${vertex(x, y + 1)}`;
  const edges: string[] = [];
  for (const { x, y } of area.tiles) {
    // N-E borders (x, y-1), E-S (x+1, y), S-W (x, y+1), W-N (x-1, y).
    if (!inside.has(`${x},${y - 1}`)) edges.push(`M${vertex(x, y)}L${vertex(x + 1, y)}`);
    if (!inside.has(`${x + 1},${y}`)) edges.push(`M${vertex(x + 1, y)}L${vertex(x + 1, y + 1)}`);
    if (!inside.has(`${x},${y + 1}`)) edges.push(`M${vertex(x + 1, y + 1)}L${vertex(x, y + 1)}`);
    if (!inside.has(`${x - 1},${y}`)) edges.push(`M${vertex(x, y + 1)}L${vertex(x, y)}`);
  }
  const outline = edges.join("");
  return (
    <svg className="cb-world__area" width="1" height="1" aria-hidden="true">
      {area.tiles.map((tile) => (
        <polygon key={`a${tile.x},${tile.y}`} points={diamond(tile)} className="cb-world__area-tint" />
      ))}
      {(area.planted ?? []).map((tile) => (
        <polygon key={`p${tile.x},${tile.y}`} points={diamond(tile)} className="cb-world__area-planted" />
      ))}
      <path d={outline} className="cb-world__area-under" />
      <path d={outline} className="cb-world__area-ring" />
    </svg>
  );
}
