Each numbered section below lands as its own PR. Sections 4.x are one asset family each. Each family PR regenerates only its own PNGs, attaches a before/after in-game screenshot (one simulator, via the verify skill), and passes `make sprites-verify`.

## 1. Tooling: IsoKit and generators (no visible change)

- [x] 1.1 Create the `Tools/IsoKit` SwiftPM package (macOS 15, executable `isokit`) from the Kit-proof prototype:
  - modules: `Geometry`, `Rig`, `Renderer`, `Materials` (finishes), `Parts`, `Props`, `Recipe`, `Catalog`, `CellFit`, `RenderJob`, `Recipes/` and the `isokit` CLI
  - add `Tools` to `.swiftlint.yml` `included` (SwiftFormat already covers it)
  - every recipe gets a building plot slab over its whole footprint, which grounds the sprite (`not_grounded`); the slab overhangs the front edges by 12 cm so the cell crops a solid bottom row
- [x] 1.2 Tests-first: IsoKit tests for the `iso-art-kit` scenarios "Recipes cannot add lights", "Recipes use shared finishes", "A recipe taller than its cell is rejected", "A 2×2 house renders 128 points wide" and "Every catalogued building kind has a recipe" (the registry against the catalog, including each migrated entry's sprite list). Render tests skip when `ISOKIT_SKIP_RENDER=1`; CI sets it
- [x] 1.3 Implement to green: recipe registry (an entry may own several recipes, e.g. house tiers), cell-fit check with pure projection maths (design D2), finish-only materials (D3)
- [x] 1.4 Implement the CLI:
  - `isokit render --catalog <dir> --out <dir>` writes raw RGBA `@1x` and `@2x` PNGs for the recipes of every `source = "isokit"` entry; `art.finalize` quantizes them into the atlases (D8)
  - `isokit render --all --out <dir>` renders every recipe to a scratch directory, whatever the catalog says
  - `isokit check` runs the registry and cell-fit checks without a GPU
  - construction stages 0–2 (generic height cuts with scaffold unless the recipe stages itself) (D4)
  - operational frames composited from moving parts (D4)
- [x] 1.5 Verification: `art.compare` compares each fresh raw render with its committed indexed PNG, premultiplied, within the measured tolerance (D5: mean ≤ 1.5/255, ≤ 0.3% of pixels off by > 24), naming each failing PNG with its numbers. Scenario test "Entries not yet migrated are left alone" in IsoKit, and the legacy pipeline now skips `isokit`/`svg` entries
- [x] 1.6 Move the terrain generator to `scripts/art/` (`terrain_tiles`, `svg_sprites`, `finalize`, `compare`, `atlas`) in the sprites venv. `pytest` covers "Both transition sets are complete", "Neighbouring transition tiles join without a seam", "Unchanged recipes pass verification" and "A changed recipe without re-rendered PNGs fails verification"; `scripts/check-scenario-coverage.swift` now reads `Tools/*/Tests` and `@pytest.mark.scenario(...)`
- [x] 1.7 `Makefile`:
  - `sprites` = `isokit render` + `art.svg_sprites`, both limited to migrated entries, then `art.finalize`
  - `sprites-verify` = `sprites-art-verify` (render + `art.compare`) + the legacy `sprites-regen-check` + `sprites-content`
  - `sprites-check` (no GPU); `art.svg_sprites` fails with a `brew install librsvg` hint when it has work and no `rsvg-convert`
  - the old online pipeline moves to `sprites-ai`; the other old targets stay until §5
- [x] 1.8 With no entry migrated yet:
  - `make sprites` leaves every atlas PNG unchanged (`git status` is clean)
  - `make sprites-verify` passes
  - `isokit render --all --out <tmp>` renders every recipe, which proves the tooling end to end without touching assets

## 2. Content gate and naming for the new rules

- [x] 2.1 Tests-first in `Packages/CityRender2D`: tests for the `sprite-asset-pipeline` scenarios "Transition tile name accepted", "Transition tile with an undeclared pair rejected", "Transition mask out of range rejected", "Content gate accepts sails sweeping past the wall", "Rendered buildings without an outline pass", "Content gate rejects a floating rendered building", "Every committed terrain sprite fills the diamond" (with bleed), "Content gate rejects an under-filled tile", "Walker frames have the walker size", "Every facing has four gait frames", "Every atlas PNG has an @2x twin" and "Verification fails on a content defect"; pytest for "make sprites runs offline" and "Every atlas PNG has a recipe or an SVG source"
- [x] 2.2 Implement to green:
  - the naming validator's `t<mask>` slot and pair list
  - the gate reads the catalog (`GateCatalog`): each brief's `source`, and the edge its moving part sweeps (`- Moving part: sails, 4 frames, sweeps right`), which is exempt from the silhouette check
  - drop `outline_missing` and keep `not_grounded`
  - terrain: no transparent pixel inside the diamond, nothing opaque beyond a 1-point bleed (every legacy tile already fills its diamond, so the rule applies to all terrain)
  - `@2x` names compare against their `@2x` base; walker size, four gait frames and the `@2x` twin check apply to migrated (`isokit`/`svg`) briefs only, so legacy families keep their shape until they flip
- [x] 2.3 Catalog briefs: a `Recipe` section in the 96 non-image-API briefs (the three image-API goods icons get theirs when they migrate in §4.9), `Sheet`/`Animation` kept until each family flips, and the catalog-section test. IsoKit's registry checks a migrated brief's stage, frame and moving-part facts against its recipe. The catalog pre-commit hook now asks for sheet edits only on image-API briefs, whose text feeds the sheet cache

## 3. Renderer: transitions and filtering

- [x] 3.1 Tests-first in CityRender2D: tests for the `rendering-2_5d` scenarios "Grass meeting beach picks a transition tile", "Grass beside water shows a beach edge", "Transitions do not change gameplay", "Building textures filter linearly" and "Goods icons stay pixel art"
- [x] 3.2 A pure `TerrainCorners` (vertex terrain with forest and mountain counted as grass, beach where grass meets water, corner mask); `SnapshotReconciler` carries the transition in `SpriteSpec.Kind.terrain(_:transition:)`, and the node factory draws it when the atlas has the tile, else the tile's own sprite. A transition beats the seasonal sprite: shore shape outranks seasonal tint, so autumn and winter grass on a shore keeps its blend (in spring colours until seasonal transition tiles exist)
- [x] 3.3 `TextureFiltering` routes every atlas texture: art-kit entries (`kitRenderedEntries`, extended by each family PR) are `.linear`, goods icons and badges `.nearest`, legacy pixel art `.nearest` until its family migrates (linear-filtered pixel art would blur during the rollout). SpriteKit picks the `@2x` atlas images; confirmed on device with the first family (4.1). SpriteKit filters a whole atlas page with one mode, so kit renders move to their own `Kit` atlas and legacy sprites need no `@2x` twins (D7)
- [ ] 3.4 Measure atlas memory on the Apple TV simulator before and after — moved into 4.1, the first PR that ships `@2x` art

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
