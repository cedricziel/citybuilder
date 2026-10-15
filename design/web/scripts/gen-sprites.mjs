// Inlines the app's sprites from Resources/*.atlas as data URIs, so the
// bundle carries its own images. Output is gitignored; build reruns it.
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const resources = join(here, "../../../Resources");
const out = join(here, "../src/generated");

const sizes = {};

function atlas(name, prefix, keep) {
  const dir = join(resources, name);
  const entries = {};
  for (const file of readdirSync(dir).sort()) {
    if (!file.endsWith(".png") || !file.startsWith(prefix)) continue;
    const key = file.slice(prefix.length, -4);
    if (!keep(key)) continue;
    const png = readFileSync(join(dir, file));
    sizes[prefix + key] = [png.readUInt32BE(16), png.readUInt32BE(20)];
    entries[key] = `data:image/png;base64,${png.toString("base64")}`;
  }
  return entries;
}

const goods = atlas("Icons.atlas", "good-", () => true);
const cultureOrEra = /-(east-asian|mediterranean|middle-eastern|antiquity|renaissance|industrial|modern)$/;
// Art-kit renders live in Kit.atlas at @1x and @2x; the web pages take the @1x base sprites.
const oneX = (key) => !key.includes("@");
const buildingBase = (key) =>
  oneX(key) && !/-(constructing|operational)-\d$/.test(key) && !cultureOrEra.test(key) && !/-v\d$/.test(key);
const buildings = { ...atlas("Buildings.atlas", "building-", buildingBase), ...atlas("Kit.atlas", "building-", buildingBase) };
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
emit("buildings.ts", "buildingSprites", buildings);
emit("terrain.ts", "terrainSprites", terrain);
const buildingSizes = Object.fromEntries(
  Object.keys(buildings).map((key) => [key, sizes[`building-${key}`]]),
);
writeFileSync(
  join(out, "buildingSizes.ts"),
  `import type { buildingSpritesKey } from "./buildings";\nexport const buildingSizes: Record<buildingSpritesKey, [number, number]> = ${JSON.stringify(buildingSizes)};\n`,
);
console.log(
  `sprites: ${Object.keys(goods).length} goods, ${Object.keys(buildings).length} buildings, ${Object.keys(terrain).length} terrain`,
);
