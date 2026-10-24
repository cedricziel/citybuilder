import { Glass } from "../Glass/Glass";
import { defaultIsland, defaultTown, type PlacedBuilding } from "../WorldBackdrop/WorldBackdrop";
import { buildingFootprints } from "../../generated/buildingFootprints";
import { terrainOf } from "../WorldBackdrop/terrain";
import "./Minimap.css";

/** The minimap's terrain colours (MinimapPalette). */
const terrainColour = {
  water: "#3B78B0",
  beach: "#E6D08A",
  grass: "#7DB35A",
  forest: "#2E6631",
  mountain: "#8A8478",
} as const;

/** Owner colours: the player's gold and the rivals' crimson, azure and emerald (RivalColour). */
export const ownerColours = {
  player: "#D4A017",
  crimson: "#B03A2E",
  azure: "#2E6DB4",
  emerald: "#2E8B57",
} as const;

export type MinimapOwner = keyof typeof ownerColours;

export interface MinimapBuilding extends PlacedBuilding {
  /** Who owns it; picks the marker colour. Default `player`. */
  owner?: MinimapOwner;
}

export interface MinimapShip {
  /** Position in map tiles; fractions allowed while sailing. */
  x: number;
  y: number;
  owner?: MinimapOwner;
}

export interface MinimapProps {
  /** The map rows, as for `WorldBackdrop`: `~` water, `.` beach, `,` grass, `T` forest, `^` mountain. */
  map?: string[];
  /** Buildings, drawn as their footprints in the owner's colour with a white outline. */
  buildings?: MinimapBuilding[];
  ships?: MinimapShip[];
  /**
   * What the camera shows: the tile at the view's centre and how many tiles
   * fit across it; drawn as a white frame. Omit to hide it.
   */
  camera?: { x: number; y: number; tilesAcross: number };
  /** The map image size: `phone` 144x72, `pad` 224x112, `mac` 240x120. Default `pad`. */
  device?: "phone" | "pad" | "mac";
}

const sizes = { phone: [144, 72], pad: [224, 112], mac: [240, 120] } as const;

/**
 * The corner minimap: terrain, every building's footprint in its owner's
 * colour, ships as dots and the camera's view as a white frame, on a 12pt
 * glass card. A tap or drag moves the camera there.
 */
export function Minimap({ map = defaultIsland, buildings = defaultTown, ships = [], camera, device = "pad" }: MinimapProps) {
  const rows = map.length;
  const cols = Math.max(...map.map((row) => row.length));
  const [width, height] = sizes[device];
  // Iso space: tile (x, y)'s top corner sits at (x - y, (x + y) / 2); the map spans x in [-rows, cols].
  const corner = (x: number, y: number) => `${x - y + rows},${(x + y) / 2}`;
  const diamond = (x: number, y: number, w = 1, h = 1) => `${corner(x, y)} ${corner(x + w, y)} ${corner(x + w, y + h)} ${corner(x, y + h)}`;
  const tiles = [];
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      tiles.push(<polygon key={`${x},${y}`} points={diamond(x, y)} fill={terrainColour[terrainOf(map[y]?.[x])]} />);
    }
  }
  const viewWidth = cols + rows;
  const viewHeight = (cols + rows) / 2;
  const frame = camera
    ? (() => {
        const w = camera.tilesAcross;
        const h = w * (height / width);
        const cx = camera.x + 0.5 - (camera.y + 0.5) + rows;
        const cy = (camera.x + camera.y + 1) / 2;
        return { x: cx - w / 2, y: cy - h / 2, w, h };
      })()
    : null;
  return (
    <Glass radius={12} padding={4} className="cb-minimap">
      <svg width={width} height={height} viewBox={`0 0 ${viewWidth} ${viewHeight}`} preserveAspectRatio="none" role="img" aria-label="Minimap">
        <rect x="0" y="0" width={viewWidth} height={viewHeight} fill={terrainColour.water} />
        <g shapeRendering="crispEdges">{tiles}</g>
        {buildings
          .filter((building) => !building.ghost)
          .map((building, index) => {
            const [w, h] = buildingFootprints[building.art];
            return (
              <polygon
                key={`b${index}`}
                points={diamond(building.x, building.y, w, h)}
                fill={ownerColours[(building as MinimapBuilding).owner ?? "player"]}
                stroke="rgba(255,255,255,0.85)"
                strokeWidth="0.75"
                vectorEffect="non-scaling-stroke"
              />
            );
          })}
        {ships.map((ship, index) => (
          <ellipse
            key={`s${index}`}
            cx={ship.x + 0.5 - (ship.y + 0.5) + rows}
            cy={(ship.x + ship.y + 1) / 2}
            rx={Math.max(viewWidth / 120, 0.35)}
            ry={Math.max(viewWidth / 120, 0.35) / 2}
            fill={ownerColours[ship.owner ?? "player"]}
            stroke="#ffffff"
            strokeWidth="0.75"
            vectorEffect="non-scaling-stroke"
          />
        ))}
        {frame ? (
          <rect
            x={frame.x}
            y={frame.y}
            width={frame.w}
            height={frame.h}
            fill="none"
            stroke="#ffffff"
            strokeWidth="1.5"
            vectorEffect="non-scaling-stroke"
          />
        ) : null}
      </svg>
    </Glass>
  );
}
