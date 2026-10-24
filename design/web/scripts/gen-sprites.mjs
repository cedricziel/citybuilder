// Inlines the app's sprites from Resources/*.atlas as data URIs, so the
// bundle carries its own images. Output is gitignored; build reruns it.
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const resources = join(here, "../../../Resources");
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

// Every atlas holds @1x and @2x files; the web pages take the @1x ones, except the goods icons:
// they are drawn at 14 and 16 px from a 24 px icon, so the @2x one keeps them sharp on a Retina screen.
const oneX = (key) => !key.includes("@");
const goods = atlas("Kit.atlas", "good-", (key) => key.endsWith("@2x"), (key) => key.slice(0, -3));
// The building status icons: a 28 px cell drawn at 20–30 px, so the @2x files keep them sharp too.
const status = atlas("Kit.atlas", "status-", (key) => key.endsWith("@2x"), (key) => key.slice(0, -3));
const cultureOrEra = /-(east-asian|mediterranean|middle-eastern|antiquity|renaissance|industrial|modern)$/;
const buildingBase = (key) =>
  oneX(key) && !/-(constructing|operational)-\d$/.test(key) && !cultureOrEra.test(key) && !/-v\d$/.test(key) &&
  !/-c\d+$/.test(key) && // road connection tiles: the backdrop draws the base road
  !/-lights(-\d+)?$/.test(key); // night-lights masks are drawn over a building, not on their own
const buildings = atlas("Kit.atlas", "building-", buildingBase);
// Base terrain tiles only: no animation frames, rock variants or transitions (seasonal sets included).
const terrain = atlas(
  "Kit.atlas",
  "terrain-",
  (key) => oneX(key) && !/-\d$/.test(key) && !/-v\d$/.test(key) && !/-t\d+/.test(key),
);

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
emit("status.ts", "statusSprites", status);
emit("buildings.ts", "buildingSprites", buildings);
emit("terrain.ts", "terrainSprites", terrain);
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
console.log(
  `sprites: ${Object.keys(goods).length} goods, ${Object.keys(status).length} status icons, ${Object.keys(buildings).length} buildings, ${Object.keys(terrain).length} terrain`,
);
