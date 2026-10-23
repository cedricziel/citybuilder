## Why

The owner wants the world to feel like a living, realistic Anno town (#84). Today's sprites do not get there. 96 of the 99 catalog entries are drawn by a Python/PIL "procedural" register, and the 3 goods icons come from the OpenAI image API. Terrain tiles are single-type diamonds with hard edges and no shoreline. Buildings are small flat-shaded boxes. Nothing in the pipeline can produce real materials, soft light or blended terrain.

Two art-direction rounds on the "Citybuilder art direction" canvas settled the look. Buildings are **pre-rendered 3D**, authored as SceneKit code and rendered through the game's 2:1 isometric camera, the way classic Anno was made. Terrain is **painterly 2D tiles** with generated grass/beach/water transitions. The "Kit proof" showed six buildings rendered with one kit:

- the peasant and citizen houses, town center, sawmill (with animated sails), lumberjack hut and forester
- all consistent on a tile-built island
- 36 sprites in about 1.1 s
- 19–38 lines per building recipe

This change turns that prototype into the source-controlled pipeline that writes the atlases. It retires the procedural and generative path.

## What Changes

- **New render tool `IsoKit`** (a SwiftPM package under `Tools/IsoKit`, not linked into the app). It holds:
  - the shared camera, light rig, finishes and parts
  - one recipe per building kind and unit
  - construction stages and moving-part frames

  `make sprites` builds it with `xcrun swift` and writes every building and unit PNG, with no network and no API key. The kit prototype in `.claude/skills/iso-sprite-authoring/kit/` (#87) is the starting point.
- **Terrain transition tiles.** A generator writes corner-mask transition tiles for grass↔beach and beach↔water (14 masks each), plus full-tile variants, as SVG. These are rendered to PNG. **BREAKING for the renderer:** it now picks each tile from the terrain at its four corners, not from the tile's own kind alone. Forest and mountain keep their current tiles in this change.
- **@2× atlases with linear filtering** for terrain, building and unit textures and the goods icons. Status badges stay pixel art with nearest filtering.
- **Walkers** move to the kit in `realistic-walkers`.
- **Remove the generative pipeline:**
  - `scripts/generate_sprites_ai/`
  - `Resources/Sprites.style/_sheets/`, `master-reference.png` and the model pin in `pipeline.toml`
  - the `sprites-reference` target, and every OpenAI key path
- **Goods icons** move to hand-authored SVG sources rendered by the same SVG step.
- **`world.md` is rewritten** as the kit's style bible: camera, light rig, finishes and tiers, terrain, animation and forbidden practices. Catalog entries stay as per-sprite briefs and now name a recipe instead of a sheet layout.
- **Verification changes.** The byte-identical regen check becomes a tolerance check, because GPU renders vary by up to 32/255 in about 0.01% of pixels between runs. The outline-colour rule is dropped, since 3D renders have no drawn outline. The grounding rule stays.
- **Rollout one asset family per PR**, each with a before/after in-game screenshot:
  1. houses
  2. forestry
  3. civic and storage
  4. food and craft chains
  5. culture and age variants
  6. ships and shore buildings
  7. walkers
  8. terrain transitions
  9. icons

## Capabilities

### New Capabilities

- `iso-art-kit`: the IsoKit render tool and terrain generator. Covers the camera and cell geometry, the shared light rig and finishes, recipes, construction stages, moving-part frames, offline rendering and the tolerance regen check.

### Modified Capabilities

- `sprite-asset-pipeline`:
  - The naming grammar gains terrain transition tiles.
  - Atlas PNGs come from IsoKit and the terrain generator.
  - Regeneration is offline and checked with a tolerance.
  - Building sprites must sit on their footprint, but no outline colour is required.
  - Terrain sprites fill the diamond with a 1-pixel bleed.
  - Moving-part frames are exempt from the silhouette rule.
- `sprite-style-catalog`:
  - The style bible describes the kit.
  - Catalog entries name a recipe.
  - The master reference, sheet slicing, prompt-hash cache, model pin and two-pass mode are removed.
  - World sprites share one rendered register.
- `rendering-2_5d`:
  - Terrain transitions are picked from corner terrain.
  - World textures are @2× and linearly filtered.

## Impact

- **Code:**
  - `Packages/CityRender2D`: the terrain tile selection in `IsoWorldScene`, texture filtering in `SpriteAtlas` and the scene factories, and the content gate (`sprite-content-gate`).
  - `CityCore` is untouched.
- **Tooling:**
  - New `Tools/IsoKit` package.
  - The terrain and icon SVG generator moves to `scripts/art/` and runs in the existing sprites venv.
  - `rsvg-convert` becomes a documented local dependency.
  - The `Makefile` sprite targets and `.swiftlint.yml` `included` gain `Tools`.
- **Assets:** every PNG in `Resources/{Terrain,Buildings,Units,Icons}.atlas/` is regenerated, family by family. The `@2x` files roughly double atlas pixels. Indexed 256-colour encoding stays, and it measured 5.4× smaller than RGBA on kit renders with no visible loss.
- **CI:** the content gate keeps running on every PR. The render regen check needs Metal, so it runs locally through `make sprites-verify`, and in CI only where the runner has a GPU.
- **Docs:** `Resources/Sprites.style/world.md`, the README sprite workflow, and the `iso-sprite-authoring` and `art-direction-canvas` skills.
