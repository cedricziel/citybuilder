// The world view's ground rules, ported from CityRender2D so the backdrop picks the same sprites:
// grass variants by tile hash (SpriteAtlas), shore transitions from corner terrain (TerrainCorners),
// and tree clumps and rock outcrops thinning toward their region's edge (TerrainObjects).
import { terrainSprites, type terrainSpritesKey } from "../../generated/terrain";
import { terrainObjectSprites, type terrainObjectSpritesKey } from "../../generated/terrainObjects";

export type Terrain = "water" | "beach" | "grass" | "forest" | "mountain";
export type Season = "summer" | "autumn" | "winter";

const charTerrain: Record<string, Terrain> = { "~": "water", ".": "beach", ",": "grass", T: "forest", "^": "mountain" };

/** The terrain of a map character; anything unknown, and everything off the map, is sea. */
export function terrainOf(ch: string | undefined): Terrain {
  return (ch && charTerrain[ch]) || "water";
}

/** SpriteAtlas.tileHash: a well-mixed 32-bit hash of a lattice point; salt 0 is the variant hash. */
export function tileHash(x: number, y: number, salt = 0): number {
  let hash = (Math.imul(x, 0x9e3779b1) + Math.imul(y, 0x6d2b79f5) + Math.imul(salt, 0x85ebca6b)) >>> 0;
  hash = (hash ^ (hash >>> 16)) >>> 0;
  hash = Math.imul(hash, 0x7feb352d) >>> 0;
  hash = (hash ^ (hash >>> 15)) >>> 0;
  return hash;
}

function variantIndex(x: number, y: number, count: number): number {
  return count > 1 ? tileHash(x, y) % count : 0;
}

/** Forest and mountain stand on grass; their trees and rock are objects over it. */
function blendClass(kind: Terrain): Terrain {
  return kind === "forest" || kind === "mountain" ? "grass" : kind;
}

/** The terrain at a vertex: a vertex touching both grass and water is beach, so beach always separates them. */
function vertexTerrain(vx: number, vy: number, at: (x: number, y: number) => Terrain): Terrain {
  const around = [
    [-1, -1],
    [0, -1],
    [-1, 0],
    [0, 0],
  ].map(([dx, dy]) => blendClass(at(vx + dx, vy + dy)));
  if (around.includes("grass") && around.includes("water")) return "beach";
  if (around.includes("water")) return "water";
  if (around.includes("beach")) return "beach";
  return "grass";
}

function seasonalName(name: string, season: Season): string {
  return season === "summer" ? name : `${name}-${season}`;
}

function sprite(names: string[]): terrainSpritesKey {
  return (names.find((name) => name in terrainSprites) ?? "water") as terrainSpritesKey;
}

/** The ground sprite of tile (x, y): a shore transition where its corners disagree, else its look. */
export function groundSprite(x: number, y: number, at: (x: number, y: number) => Terrain, season: Season): terrainSpritesKey {
  const corners = [
    [0, 0],
    [1, 0],
    [1, 1],
    [0, 1],
  ].map(([dx, dy]) => vertexTerrain(x + dx, y + dy, at));
  if (new Set(corners).size === 2) {
    const [upper, lower] = corners.includes("grass") ? ["grass", "beach"] : ["beach", "water"];
    const mask = corners.reduce((bits, corner, index) => (corner === upper ? bits | (1 << index) : bits), 0);
    const name = `${upper}-${lower}-t${mask}`;
    return sprite(upper === "grass" ? [seasonalName(name, season), name] : [name]);
  }
  const floor = blendClass(at(x, y));
  if (floor !== "grass") return sprite([floor]);
  const stem = season === "summer" ? "grass" : `grass-${season}`;
  const variant = variantIndex(x, y, 4);
  return sprite(variant === 0 ? [stem] : [`${stem}-v${variant}`, stem]);
}

type Density = "sparse" | "medium" | "dense" | "peak";
const ladder: Density[] = ["sparse", "medium", "dense"];

/**
 * Edge-neighbour steps from each tile of `kind` to the nearest tile that is not (1 on the edge), by
 * breadth-first search; the map's border counts as an edge.
 */
function edgeDistances(kind: Terrain, cols: number, rows: number, at: (x: number, y: number) => Terrain): number[] {
  const distance = new Array<number>(cols * rows).fill(0);
  const queue: number[] = [];
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      if (at(x, y) !== kind) continue;
      const edge = [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ].some(([dx, dy]) => {
        const nx = x + dx;
        const ny = y + dy;
        return nx < 0 || ny < 0 || nx >= cols || ny >= rows || at(nx, ny) !== kind;
      });
      if (edge) {
        distance[y * cols + x] = 1;
        queue.push(y * cols + x);
      }
    }
  }
  for (let head = 0; head < queue.length; head++) {
    const index = queue[head];
    const x = index % cols;
    const y = Math.floor(index / cols);
    for (const [dx, dy] of [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ]) {
      const nx = x + dx;
      const ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
      const next = ny * cols + nx;
      if (at(nx, ny) !== kind || distance[next] !== 0) continue;
      distance[next] = distance[index] + 1;
      queue.push(next);
    }
  }
  return distance;
}

export interface PlacedObject {
  x: number;
  y: number;
  art: terrainObjectSpritesKey;
}

/**
 * Every tree clump and rock outcrop on the map. Edge tiles are sparse (one in three medium), the
 * next ring medium, the interior dense; a tile next to a building drops one step. Deep rock turns
 * to tall tors by tile hash, where the game reads smooth world noise.
 */
export function terrainObjects(
  cols: number,
  rows: number,
  at: (x: number, y: number) => Terrain,
  occupied: Set<string>,
  season: Season,
): PlacedObject[] {
  const forest = edgeDistances("forest", cols, rows, at);
  const rock = edgeDistances("mountain", cols, rows, at);
  const crowded = (x: number, y: number) => {
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if ((dx || dy) && occupied.has(`${x + dx},${y + dy}`)) return true;
    return false;
  };
  const objects: PlacedObject[] = [];
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      const kind = at(x, y);
      if ((kind !== "forest" && kind !== "mountain") || occupied.has(`${x},${y}`)) continue;
      const distance = (kind === "forest" ? forest : rock)[y * cols + x];
      const less = crowded(x, y) ? 1 : 0;
      let density: Density;
      if (kind === "forest") {
        let step = Math.min(distance, 3) - 1;
        if (distance === 1 && tileHash(x, y, 7) % 3 === 0) step = 1;
        density = ladder[Math.max(0, step - less)];
      } else {
        const step = Math.max(0, Math.min(distance, 3) - 1 - less);
        density = step === 2 && distance >= 4 && tileHash(x, y, 11) % 3 === 0 ? "peak" : ladder[step];
      }
      const stem = `${kind}-${density}`;
      const look = season === "summer" || (kind === "mountain" && season === "autumn") ? stem : `${stem}-${season}`;
      const variant = variantIndex(x, y, 4);
      const names = variant === 0 ? [look, stem] : [`${look}-v${variant}`, look, `${stem}-v${variant}`, stem];
      const art = names.find((name) => name in terrainObjectSprites) as terrainObjectSpritesKey | undefined;
      if (art) objects.push({ x, y, art });
    }
  }
  return objects;
}
