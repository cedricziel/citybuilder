Each numbered section below lands as its own PR. Sections 4.x are one asset family each. Each family PR regenerates only its own PNGs, attaches a before/after in-game screenshot (one simulator, via the verify skill), and passes `make sprites-verify`.

## 1. Tooling: IsoKit and generators (no visible change)

- [ ] 1.1 Create the `Tools/IsoKit` SwiftPM package (macOS 15, executable `isokit`) from `.claude/skills/iso-sprite-authoring/kit/`:
  - split it into `Kit`, `Finishes`, `Parts`, `Props`, `Recipes` and `CLI`
  - add `Tools` to `.swiftlint.yml` `included` and to the SwiftFormat config
- [ ] 1.2 Tests-first: write failing IsoKit tests for the `iso-art-kit` scenarios "Recipes cannot add lights", "Recipes use shared finishes", "A recipe taller than its cell is rejected", "A 2×2 house renders 128 points wide" and "Every catalogued building kind has a recipe" (the registry against the catalog). Confirm they are red
- [ ] 1.3 Implement to green: recipe registry, cell-height check (design D2), finish-only materials (D3)
- [ ] 1.4 Implement the CLI:
  - `isokit render <Resources>` writes `@1x` and `@2x` PNGs for every catalog entry with `source = "isokit"`, quantized to indexed 256 colours (D8)
  - `isokit render --all --out <dir>` renders every recipe to a scratch directory, whatever the catalog says
  - construction stages 0–2 (D4)
  - operational frames composited from moving parts (D4)
- [ ] 1.5 Implement `isokit verify <Resources>`: re-render the `source = "isokit"` entries to a temp dir and apply the tolerance (D5), printing each failing PNG with its mean and outlier fraction. Add the scenario test "Entries not yet migrated are left alone". The SVG generator gets the same `verify` mode for `source = "svg"` entries
- [ ] 1.6 Move the terrain and icon SVG generator to `scripts/art/` in the sprites venv, using the prototype `terrain/transitions.py`. Add a `pytest` for "Both transition sets are complete" and "Neighbouring transition tiles join without a seam"
- [ ] 1.7 `Makefile`:
  - `sprites` = `isokit render Resources` + the SVG generator's render, both limited to migrated entries
  - `sprites-verify` = `isokit verify Resources` + the SVG generator's verify + `sprites-content`
  - add a `rsvg-convert` presence check with an install hint
  - keep the old targets until §5
- [ ] 1.8 With no entry migrated yet:
  - `make sprites` leaves every atlas PNG unchanged (`git status` is clean)
  - `make sprites-verify` passes
  - `isokit render --all --out <tmp>` renders every recipe, which proves the tooling end to end without touching assets

## 2. Content gate and naming for the new rules

- [ ] 2.1 Tests-first in `Packages/CityRender2D`: write failing tests for the `sprite-asset-pipeline` scenarios "Transition tile name accepted", "Transition tile with an undeclared pair rejected", "Transition mask out of range rejected", "Content gate accepts sails sweeping past the wall", "Rendered buildings without an outline pass", "Every committed terrain sprite fills the diamond" (with bleed), "Walker frames have the walker size" and "Every atlas PNG has an @2x twin"
- [ ] 2.2 Implement to green:
  - the naming validator's `t<mask>` slot and pair list
  - the moving-part silhouette exemption, read from the catalog `Recipe` section
  - drop `outline_missing` and keep `not_grounded`
  - diamond coverage with a 1-point bleed
  - walker size
  - the @2x twin check (gated on a per-family allow-list until §4 completes)
- [ ] 2.3 Catalog briefs: add a `Recipe` section to every `catalog/<id>.md` and keep `Sheet`/`Animation` until each family flips. Add the catalog-section test for "Catalog entry declares all required sections"

## 3. Renderer: transitions and filtering

- [ ] 3.1 Tests-first in CityRender2D: write failing tests for the `rendering-2_5d` scenarios "Grass meeting beach picks a transition tile", "Grass beside water shows a beach edge", "Transitions do not change gameplay", "Building textures filter linearly" and "Goods icons stay pixel art"
- [ ] 3.2 Implement a pure `TerrainCorners` function (vertex rank, grass-water demotion, mask), and use it in tile reconciliation and `SpriteAtlas` lookup
- [ ] 3.3 Switch world textures to `.linear` and keep icons and badges on `.nearest`. Confirm SpriteKit loads the `@2x` atlas images on retina devices and on Apple TV
- [ ] 3.4 Measure atlas memory on the Apple TV simulator before and after, and record it in design D7

## 4. Rollout, one family per PR

- [ ] 4.1 Houses: every tier (peasant, citizen, merchant) for the default culture, with construction stages. Check Apple TV memory here
- [ ] 4.2 Forestry: lumberjack hut, forester and sawmill (sails moving part), charcoal burner
- [ ] 4.3 Civic and storage: town center, warehouse, market, library, road variants
- [ ] 4.4 Food and craft chains: farm, grain farm, windmill (sails), bakery, brewery, mine, smelter, toolsmith and the remaining production kinds
- [ ] 4.5 Culture and age variants: culture buildings, age houses and signature buildings (`sprite-style-catalog` culture and age requirements)
- [ ] 4.6 Ships and shore buildings: port and shipyard in four orientations (resolve the open question in design.md), ship facings
- [ ] 4.7 Walkers: kit figure recipe, 10×16, 4 facings × 4 gait frames, tunic colour by job. Update the walker node size in the renderer
- [ ] 4.8 Terrain: grass/beach/water full tiles and both transition sets, season variants (`Terrain shows the season`), lands together with §3
- [ ] 4.9 Goods icons: hand-authored SVG sources replace the three image-API icons and the procedural ones

## 5. Retire the old pipeline and docs

- [ ] 5.1 Delete `scripts/generate_sprites_ai/`, `Resources/Sprites.style/_sheets/`, `master-reference.png`, `_cache/` and the `model` key, and the `sprites-reference`, `sprites-procedural` and `sprites-offline` targets. Remove `Sheet`/`Animation` from the catalog briefs
- [ ] 5.2 Rewrite `Resources/Sprites.style/world.md` with the sections of "Style bible declares the kit's visual identity", using values that match IsoKit. Add the section test
- [ ] 5.3 Rewrite the README sprite workflow, and update the `iso-sprite-authoring` skill to point at `Tools/IsoKit` instead of the prototype
- [ ] 5.4 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `iso-art-kit`, `sprite-asset-pipeline`, `sprite-style-catalog` or `rendering-2_5d`
- [ ] 5.5 Run the verify skill: one walk through a coastal start with every family on screen. Attach the screenshot to the archive PR
