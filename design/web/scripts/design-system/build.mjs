// Builds the Citybuilder design system's files from design/web, in the layout the published system
// uses (`_ds_bundle.js`, `_preview/<Name>.js`, `components/<group>/<Name>/…`), and lists which files
// differ from the published copy so they can be republished one component at a time.
//
// usage: node scripts/design-system/build.mjs [--out <dir>] [--artifact <dir>] [--since <git ref>]
//   --out       where to write `project/…` (default: design/web/ds-out)
//   --artifact  a folder holding the published system's current `project/` files (as the Artifact
//               tool's `read` saves them); with it, the manifest, README and component list are
//               updated in place instead of written fresh, and `changes.json` lists what differs.
//   --since     the commit the system was last published from: `changes.json` then lists only the
//               components whose source, docs stub or preview changed since.
// Run `npm run build` first: this reads design/web/dist.
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const web = join(here, "../..");
const repo = join(web, "../..");
const dist = join(web, "dist");
const previews = join(repo, ".design-sync/previews");
const config = JSON.parse(readFileSync(join(repo, ".design-sync/config.json"), "utf8"));
const namespace = config.globalName;

const args = process.argv.slice(2);
const option = (name) => {
  const at = args.indexOf(name);
  return at >= 0 ? args[at + 1] : undefined;
};
const out = option("--out") ?? join(web, "ds-out");
const artifact = option("--artifact");
const published = (path) => (artifact && existsSync(join(artifact, path)) ? readFileSync(join(artifact, path), "utf8") : undefined);

const require = createRequire(join(web, "package.json"));
const { build } = require("esbuild");

const written = new Map();
function write(path, text) {
  const file = join(out, path);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, text);
  written.set(path, text);
}

// The components are the docs stubs: `docs/<Name>.md` with `category: Art | HUD | Sheets | Screens | Foundations`.
const components = readdirSync(join(web, "docs"))
  .filter((file) => file.endsWith(".md"))
  .map((file) => {
    const name = file.slice(0, -3);
    const category = /^category:\s*(\w+)/m.exec(readFileSync(join(web, "docs", file), "utf8"))?.[1];
    if (!category) throw new Error(`docs/${file}: no category`);
    return { name, group: category.toLowerCase() };
  })
  .sort((a, b) => a.name.localeCompare(b.name));
const sourcePath = ({ name, group }) => `components/${group}/${name}/${name}.jsx`;
const cardPath = ({ name, group }) => `components/${group}/${name}/${name}.html`;
const cardMode = (name) => config.overrides?.[name]?.cardMode ?? "grid";

// --- The bundle, its stylesheet and the previews: React comes from the page's globals. ---------------
const reactShim = `
var R = window.React;
function np(p, k) { var o = {}; for (var x in p) if (x !== "children") o[x] = p[x]; if (k !== void 0) o.key = k; return o; }
function jsx(t, p, k) { var c = p && p.children; return c === void 0 ? R.createElement(t, np(p, k)) : R.createElement(t, np(p, k), c); }
function jsxs(t, p, k) { return R.createElement.apply(R, [t, np(p, k)].concat(p.children)); }
module.exports = R;
module.exports.jsx = jsx;
module.exports.jsxs = jsxs;
module.exports.jsxDEV = function (t, p, k, s) { return (s ? jsxs : jsx)(t, p, k); };
module.exports.Fragment = R.Fragment;
`;
const shims = (extra = {}) => ({
  name: "shims",
  setup(b) {
    const map = { react: "react", "react/jsx-runtime": "react", "react-dom": "react-dom", ...extra };
    b.onResolve({ filter: /^(react|react\/jsx-runtime|react-dom|@citybuilder\/ui)$/ }, (resolved) =>
      map[resolved.path] ? { path: map[resolved.path], namespace: "shim" } : undefined,
    );
    b.onLoad({ filter: /.*/, namespace: "shim" }, (loaded) => {
      if (loaded.path === "react") return { contents: reactShim, loader: "js" };
      if (loaded.path === "react-dom") return { contents: "module.exports = window.ReactDOM;", loader: "js" };
      return { contents: `module.exports = window.${namespace};`, loader: "js" };
    });
  },
});

const header = `/* @ds-bundle: ${JSON.stringify({ namespace, components: components.map((c) => ({ name: c.name, sourcePath: sourcePath(c) })) })} */\n`;
const bundle = await build({
  entryPoints: [join(dist, "index.js")],
  bundle: true,
  format: "iife",
  globalName: namespace,
  write: false,
  plugins: [shims()],
  logLevel: "warning",
});
write("project/_ds_bundle.js", `${header}${bundle.outputFiles[0].text}window.${namespace}=${namespace};\n`);
write("project/_ds_bundle.css", readFileSync(join(dist, "index.css"), "utf8"));

for (const { name } of components) {
  const entry = join(previews, `${name}.tsx`);
  if (!existsSync(entry)) throw new Error(`${name}: no preview at .design-sync/previews/${name}.tsx`);
  const result = await build({
    entryPoints: [entry],
    bundle: true,
    format: "iife",
    globalName: "__dsPreview",
    jsx: "automatic",
    write: false,
    plugins: [shims({ "@citybuilder/ui": "ds" })],
    logLevel: "warning",
  });
  write(`project/_preview/${name}.js`, result.outputFiles[0].text);
}

// --- Per component: types, usage note, re-export and card. -------------------------------------------
const keyTypes = {};
for (const file of readdirSync(join(dist, "generated")).filter((f) => f.endsWith(".d.ts"))) {
  const text = readFileSync(join(dist, "generated", file), "utf8");
  for (const [, key, union] of text.matchAll(/export type (\w+) = ([^;]+);/g)) keyTypes[key] = union.trim();
}
function inlineTypes(text) {
  let result = text
    .split("\n")
    .filter((line) => !/^import /.test(line))
    .join("\n");
  for (const [key, union] of Object.entries(keyTypes)) result = result.replace(new RegExp(`\\b${key}\\b`, "g"), union);
  return result.replace(/import\("react"\)\.JSX\.Element/g, "React.JSX.Element").trim();
}
function examples(name) {
  const source = readFileSync(join(previews, `${name}.tsx`), "utf8");
  const parts = [];
  for (const [, story, body] of source.matchAll(/^export const (\w+) = ([\s\S]*?);\n(?=\n|export |const |\/\*\*|$)/gm)) {
    parts.push(`### ${story}\n\n\`\`\`jsx\n${body.trim()}\n\`\`\``);
  }
  return parts.length ? `## Examples\n\n${parts.join("\n\n")}\n` : "";
}
function summaryOf(body, name) {
  const at = body.search(new RegExp(`export declare function ${name}\\b`));
  const start = body.lastIndexOf("/**", at);
  if (at < 0 || start < 0) return "";
  return body
    .slice(start + 3, body.lastIndexOf("*/", at))
    .split("\n")
    .map((line) => line.replace(/^\s*\* ?/, ""))
    .join("\n")
    .trim();
}

const template = readFileSync(join(here, "card.html"), "utf8");
const previousManifest = published("project/_ds_manifest.json");
const manifest = previousManifest
  ? JSON.parse(previousManifest)
  : {
      namespace,
      components: [],
      startingPoints: [],
      cards: [],
      templates: [],
      hasThumbnailHtml: false,
      globalCssPaths: ["_ds_bundle.css", "styles.css"],
      tokens: [],
      themes: [{ selector: ".cb-theme-dark", label: "Cb Dark" }],
      fonts: [],
      brandFonts: [],
      source: "design-sync-cli",
    };
const summaries = {};

for (const component of components) {
  const { name, group } = component;
  const dir = `project/components/${group}/${name}`;
  const body = inlineTypes(readFileSync(join(dist, "components", name, `${name}.d.ts`), "utf8"));
  summaries[name] = summaryOf(body, name);
  write(`${dir}/${name}.d.ts`, `import * as React from 'react';\n\n/**\n * ${name} — from @citybuilder/ui@0.0.0.\n */\n${body}\n`);
  const props = new RegExp(`export interface ${name}Props \\{[\\s\\S]*?\\n\\}`).exec(body);
  write(
    `${dir}/${name}.prompt.md`,
    [
      `${name} from @citybuilder/ui. Use via \`window.${namespace}.${name}\` (bundle loaded from the root \`_ds_bundle.js\`). Wrap the tree in \`<CityProvider>\` (full provider chain in README.md — components read theme/i18n from that context).`,
      "",
      summaries[name],
      "",
      "## Props",
      "",
      "```ts",
      props ? props[0].replace(/^export /, "").replace(/^ {4}/gm, "  ") : "",
      "```",
      "",
      examples(name),
    ].join("\n"),
  );
  write(
    `${dir}/${name}.jsx`,
    `// Re-export of @citybuilder/ui@0.0.0 ${name}. Implementation is in the root _ds_bundle.js (window.${namespace}).\nObject.assign(window, { ${name}: window.${namespace}.${name} });\n`,
  );
  let card = manifest.cards.find((c) => c.path === cardPath(component));
  if (!card) {
    card = cardMode(name) === "column" ? { path: cardPath(component), group, viewport: "900x700" } : { path: cardPath(component), group };
    manifest.cards.push(card);
  }
  const marker = card.viewport ? `<!-- @dsCard group="${group}" viewport="${card.viewport}" -->` : `<!-- @dsCard group="${group}" -->`;
  write(`${dir}/${name}.html`, template.replace("__DS_CARD__", marker).replaceAll("__NAME__", name).replace("__MODE__", cardMode(name)));
}

// --- The manifest: every component and card, and every token in tokens.css. --------------------------
manifest.components = components.map((c) => ({ name: c.name, sourcePath: sourcePath(c) }));
manifest.cards.sort((a, b) => a.path.localeCompare(b.path));
const tokensCss = readFileSync(join(web, "src/styles/tokens.css"), "utf8");
for (const [, selectors, block] of tokensCss.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
  const scope = selectors.includes(".cb-theme-dark") ? ".cb-theme-dark" : ".cb-root";
  for (const [, name, value] of block.matchAll(/(--cb-[\w-]+):\s*([^;]+);/g)) {
    if (manifest.tokens.some((t) => t.name === name && t.scope === scope)) continue;
    const kind = /font/.test(name) ? "font" : /radius/.test(name) ? "radius" : /shadow/.test(name) ? "shadow" : "color";
    manifest.tokens.push({ name, value: value.trim(), kind, definedIn: "_ds_bundle.css", scope });
  }
}
write("project/_ds_manifest.json", JSON.stringify(manifest));

// --- README and component list: add each component they don't name yet. -----------------------------
const readme = published("project/README.md");
if (readme) {
  let text = readme;
  for (const { name, group } of components) {
    if (text.includes(`- \`${name}\` —`)) continue;
    const heading = new RegExp(`^### ${group}\\n\\n?`, "m").exec(text);
    const first = (summaries[name].split(/(?<=\.)\s/)[0] ?? "").replace(/\n/g, " ");
    const line = `- \`${name}\` — ${first}\n`;
    text = heading ? text.slice(0, heading.index + heading[0].length) + line + text.slice(heading.index + heading[0].length) : text;
    const loads = `- **${name}** (\`project/${cardPath({ name, group })}\`) also loads \`project/_vendor/react.js\`, \`project/_vendor/react-dom.js\` and \`project/_preview/${name}.js\`.\n`;
    const slides = text.indexOf("- **Slides deck:**");
    if (!text.includes(`- **${name}** (`) && slides >= 0) text = text.slice(0, slides) + loads + text.slice(slides);
  }
  text = text.replace(/All \d+ components are the real upstream code[^\n]*/, `All ${components.length} components are the real upstream code.`);
  write("project/README.md", text);
}
const list = published("project/assets/notes/COMPONENTS.md");
if (list) {
  let text = list;
  for (const component of components) {
    if (text.includes(`| \`${component.name}\` |`)) continue;
    const base = `project/components/${component.group}/${component.name}/${component.name}`;
    text = text.replace(/\n*$/, `\n| \`${component.name}\` | \`${base}.jsx\` | \`${base}.d.ts\` | \`${base}.prompt.md\` | \`${base}.html\` |\n`);
  }
  write("project/assets/notes/COMPONENTS.md", text);
}

// --- What differs from the published copy, grouped for one publish per component. ---------------------
// With --since <ref>, only components whose source, docs stub or preview changed since that commit count;
// the others are left as published, even where a rebuild would word a file differently.
const since = option("--since");
const touched = since
  ? new Set(
      execFileSync("git", ["-C", repo, "diff", "--name-only", `${since}...HEAD`], { encoding: "utf8" })
        .split("\n")
        .flatMap((path) => {
          const match =
            /^design\/web\/src\/components\/(\w+)\//.exec(path) ??
            /^design\/web\/docs\/(\w+)\.md$/.exec(path) ??
            /^\.design-sync\/previews\/(\w+)\.tsx$/.exec(path);
          return match ? [match[1]] : [];
        }),
    )
  : null;
if (artifact) {
  const changes = { since: since ?? null, shared: [], components: {} };
  for (const [path, text] of written) {
    if (published(path) === text) continue;
    const owner = components.find((c) => path === `project/_preview/${c.name}.js` || path.startsWith(`project/components/${c.group}/${c.name}/`));
    if (owner && touched && !touched.has(owner.name)) continue;
    if (owner) (changes.components[owner.name] ??= []).push(path);
    else changes.shared.push(path);
  }
  write("changes.json", `${JSON.stringify(changes, null, 2)}\n`);
  console.log(`shared: ${changes.shared.join(", ") || "none"}`);
  for (const [name, paths] of Object.entries(changes.components)) console.log(`${name}: ${paths.length} file(s)`);
}
console.log(`design system: ${components.length} components → ${out}`);
