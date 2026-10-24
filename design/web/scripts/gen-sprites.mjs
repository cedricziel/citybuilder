// Inlines the app's sprites from Resources/*.atlas as data URIs, so the
// bundle carries its own images. Output is gitignored; build reruns it.
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, "../../..");
const resources = join(repo, "Resources");
const out = join(here, "../src/generated");

const sizes = {};

function atlas(name, prefix, keep, rename = (key) => key) {
  const dir = join(resources, name);
  const entries = {};
  for (const file of readdirSync(dir).sort()) {
    if (!file.endsWith(".png") || !file.startsWith(prefix)) continue;
    const fileKey = file.slice(prefix.length, -4);
    if (!keep(fileKey)) continue;
    const key = rename(fileKey);
    const png = readFileSync(join(dir, file));
    sizes[prefix + key] = [png.readUInt32BE(16), png.readUInt32BE(20)];
    entries[key] = `data:image/png;base64,${png.toString("base64")}`;
  }
  return entries;
}

// Every atlas holds @1x and @2x files; the web pages take the @1x ones.
const oneX = (key) => !key.includes("@");

// The goods icons are hand-authored SVG (`scripts/art/goods_icons.py`, style B); the atlas PNGs are
// renders of it. Take the SVG itself, so an icon stays sharp at any size. Without python3, fall back
// to the @2x renders.
function goodsFromSvg() {
  const program = [
    "import json, sys",
    `sys.path.insert(0, ${JSON.stringify(join(repo, "scripts"))})`,
    "from art import goods_icons",
    "print(json.dumps(goods_icons.sources()))",
  ].join("\n");
  try {
    const sources = JSON.parse(execFileSync("python3", ["-I", "-c", program], { encoding: "utf8" }));
    return Object.fromEntries(
      Object.entries(sources)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([name, svg]) => [name.slice("good-".length), `data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`]),
    );
  } catch (error) {
    console.warn(`gen-sprites: no SVG goods icons (${String(error.message).split("\n")[0]}); using the @2x renders`);
    return atlas("Kit.atlas", "good-", (key) => key.endsWith("@2x"), (key) => key.slice(0, -3));
  }
}
const goods = goodsFromSvg();

const cultureOrEra = /-(east-asian|mediterranean|middle-eastern|antiquity|renaissance|industrial|modern)$/;
const buildingBase = (key) =>
  oneX(key) && !/-(constructing|operational)-\d$/.test(key) && !cultureOrEra.test(key) && !/-v\d$/.test(key) &&
  !/-c\d+$/.test(key) && // road connection tiles: the backdrop draws the base road
  !/-lights(-\d+)?$/.test(key); // night-lights masks are drawn over a building, not on their own
const buildings = atlas("Kit.atlas", "building-", buildingBase);
// Night lights: each lit building's first evening (`building-bakery-lights-0`), added over its sprite.
const lightsSuffix = "-lights-0";
const lights = atlas(
  "Kit.atlas",
  "building-",
  (key) => oneX(key) && key.endsWith(lightsSuffix) && key.slice(0, -lightsSuffix.length) in buildings,
  (key) => key.slice(0, -lightsSuffix.length),
);
// Tree clumps and rock outcrops stand on grass as objects in a 144x132 cell; ground tiles are 64x32.
const isObject = (key) => /^(forest|mountain)-/.test(key);
// Ground tiles: the base looks, their grass variants and the shore transitions (seasonal sets
// included), without animation frames.
const terrain = atlas("Kit.atlas", "terrain-", (key) => oneX(key) && !isObject(key) && !/-\d$/.test(key));
const terrainObjects = atlas("Kit.atlas", "terrain-", (key) => oneX(key) && isObject(key));

function emit(file, exportName, entries) {
  const body = Object.entries(entries)
    .map(([key, uri]) => `  ${JSON.stringify(key)}: ${JSON.stringify(uri)},`)
    .join("\n");
  const keys = Object.keys(entries).map((key) => JSON.stringify(key)).join(" | ");
  writeFileSync(
    join(out, file),
    `export type ${exportName}Key = ${keys};\nexport const ${exportName}: Record<${exportName}Key, string> = {\n${body}\n};\n`,
  );
}

mkdirSync(out, { recursive: true });
emit("goods.ts", "goodSprites", goods);
emit("buildings.ts", "buildingSprites", buildings);
emit("terrain.ts", "terrainSprites", terrain);
emit("terrainObjects.ts", "terrainObjectSprites", terrainObjects);
const lightsBody = Object.entries(lights)
  .map(([key, uri]) => `  ${JSON.stringify(key)}: ${JSON.stringify(uri)},`)
  .join("\n");
writeFileSync(
  join(out, "lights.ts"),
  `import type { buildingSpritesKey } from "./buildings";\nexport const buildingLights: Partial<Record<buildingSpritesKey, string>> = {\n${lightsBody}\n};\n`,
);
const buildingSizes = Object.fromEntries(
  Object.keys(buildings).map((key) => [key, sizes[`building-${key}`]]),
);
writeFileSync(
  join(out, "buildingSizes.ts"),
  `import type { buildingSpritesKey } from "./buildings";\nexport const buildingSizes: Record<buildingSpritesKey, [number, number]> = ${JSON.stringify(buildingSizes)};\n`,
);

// A sprite can be wider than its footprint (room for its shadow), so the footprint comes from the
// brief that lists the sprite (`- Cell: 2×3 footprint`), not from the PNG's width.
const footprintOf = {};
const catalog = join(resources, "Sprites.style/catalog");
for (const file of readdirSync(catalog).filter((name) => name.endsWith(".md"))) {
  const text = readFileSync(join(catalog, file), "utf8");
  const cell = /^- Cell: (\d+)×(\d+) footprint/m.exec(text);
  if (!cell) continue;
  for (const [, name] of text.matchAll(/^- (?:\(\d+, *\d+\): )?`building-([a-z0-9-]+)`/gm)) {
    footprintOf[name] = [Number(cell[1]), Number(cell[2])];
  }
}
const buildingFootprints = Object.fromEntries(Object.keys(buildings).map((key) => [key, footprintOf[key] ?? [1, 1]]));
writeFileSync(
  join(out, "buildingFootprints.ts"),
  `import type { buildingSpritesKey } from "./buildings";\n// Footprint in tiles: [columns along x, rows along y].\nexport const buildingFootprints: Record<buildingSpritesKey, [number, number]> = ${JSON.stringify(buildingFootprints)};\n`,
);

// Figures and ships, every animation frame: `walker-ne-0` … `walker-ne-7` become `walker-ne: [8 frames]`,
// with each cycle's frame size.
const unitFrames = {};
const unitSizes = {};
for (const file of readdirSync(join(resources, "Kit.atlas")).sort((a, b) => a.localeCompare(b, "en", { numeric: true }))) {
  const match = /^((?:walker|carrier|animal|ship)-[a-z-]+)-(\d+)\.png$/.exec(file);
  if (!match) continue;
  const png = readFileSync(join(resources, "Kit.atlas", file));
  (unitFrames[match[1]] ??= [])[Number(match[2])] = `data:image/png;base64,${png.toString("base64")}`;
  unitSizes[match[1]] = [png.readUInt32BE(16), png.readUInt32BE(20)];
}
writeFileSync(
  join(out, "units.ts"),
  `export type unitSpritesKey = ${Object.keys(unitFrames).map((key) => JSON.stringify(key)).join(" | ")};\n` +
    `export const unitSprites: Record<unitSpritesKey, string[]> = ${JSON.stringify(unitFrames)};\n` +
    `export const unitSizes: Record<unitSpritesKey, [number, number]> = ${JSON.stringify(unitSizes)};\n`,
);

// The app icon (`scripts/art/app_icon.py`): the gable house on its grass plot, at the macOS 256 px
// size, which carries its own rounded square.
const appIcon = readFileSync(join(repo, "Apps/CitybuilderMac/Assets.xcassets/AppIcon.appiconset/icon-256.png"));
writeFileSync(
  join(out, "brand.ts"),
  `export const appIconSprite = ${JSON.stringify(`data:image/png;base64,${appIcon.toString("base64")}`)};\n`,
);

console.log(
  `sprites: ${Object.keys(goods).length} goods, ${Object.keys(buildings).length} buildings (${Object.keys(lights).length} lit), ` +
    `${Object.keys(terrain).length} terrain tiles, ${Object.keys(terrainObjects).length} terrain objects`,
);
