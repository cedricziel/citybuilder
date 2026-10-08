## Context

See proposal.md (Why) for the playtest findings. These facts about the current code shape the approach:

- **Sprite pipeline.** It's written in Python (`scripts/generate_sprites_ai/`) and makes one API call per sprite. `--verify` only checks that the committed PNGs reproduce byte-for-byte from `_sheets/` plus the cache. Every pipeline spec scenario is backed by a Swift test that inspects committed files (`SpritesStyleCatalogTests`), because `check-scenario-coverage.swift` only counts `@Test("scenario: …")` in `Packages/*/Tests`.
- **Icon loading.** `GoodIconLoader` resolves icons with `Bundle.main.url(forResource:withExtension:)`. That works in unit tests with loose PNGs, but not in the app, where Xcode compiles `*.atlas` into `*.atlasc`.
- **Food.** `Good.food` exists and houses check `hasGoodInReach(.food, …)`, but no recipe outputs food.
- **CI runners.** The sprite job runs on `macos-15`, so CoreGraphics and ImageIO are available there.

## Goals / Non-Goals

**Goals:**
- A content gate that, on today's committed art, would have failed with every defect from the playtest.
- Terrain tiles that fill their diamond, with no new art style.
- A population loop the player can close with the starter stock.

**Non-Goals:**
- Restyling buildings, walkers, or ships beyond the farm.
- The iPhone bottom-sheet palette that the `platform-shells` "iPhone compact HUD" scenario describes. That's a separate layout change. This change only stops labels from wrapping.
- Touch-first placement (`add-touch-first-placement`) and the history ages (`add-historical-ages`).

## Decisions

### D1 — The content gate is Swift, in a new `SpriteContentGate` target inside the CityRender2D package

The gate is a small library (ImageIO/CoreGraphics decode plus three metric functions) with a thin `sprite-content-gate` executable. `make sprites-verify` runs it after the Python byte check with `xcrun swift run --package-path Packages/CityRender2D --scratch-path .build/sprite-content-gate sprite-content-gate Resources`. The separate scratch path matters: `SpritesPipelineCutoverTests` runs `make sprites-verify` from inside `swift test` on the same package, and sharing the default `.build` makes the nested build wait forever on the outer build lock.

- **Alternative — Python, next to `postprocess.py`.** Rejected. Spec scenarios must map to Swift `@Test`s, so we'd need the metric in Python *and* Swift, and the two copies could disagree.
- **Alternative — a standalone `scripts/check-sprite-content.swift`.** Rejected. A script can't be unit-tested from `Packages/*/Tests`.
- **Placement:** CityRender2D already owns the atlas layout and naming grammar. Keeping the gate as a separate target means the app's `CityRender2D` library doesn't link it.

### D2 — Coherence metric: a 16-bin palette histogram, chi-squared distance

Opaque pixels are quantised into 4 luminance × 4 hue-sector bins and normalised. Frames are compared to the base sprite using chi-squared distance, with the threshold `coherence_max_distance` in `pipeline.toml`. It is pinned at 0.3: on the `e57823e` atlas, the known-good frames (grass, road variants, lumberjack, mountain-v3) score below 0.3, and the broken water and beach frames score above it. Construction stages (`-constructing-N`) are skipped, and operational frames (`-operational-N`) are compared against the kind's base sprite.

The metric cannot catch an off-subject frame drawn in a similar palette. A brown house inside the brown mountain variants passed calibration. The design accepts this (see Risks); D8 removes those particular sprites from the AI path.

- **Alternative — SSIM or a perceptual hash.** Rejected. Animation frames legitimately move pixels around (glints, saw blades). A positional metric gives false failures, while the palette distribution stays stable within one object.
- **Alternative — a CLIP or vision-model classifier.** Rejected. It's a network dependency in CI and non-deterministic.

### D3 — Diamond-fit is a pipeline post-process step for `terrain-*` only

After `postprocess.py` downsamples a terrain sprite to 64×32, it:

1. computes the alpha bounding box;
2. scales the box with nearest-neighbour to fill the 64×32 extent;
3. multiplies alpha by the canonical diamond mask (rows `y`, with half-width `32 - |2y - 31|`).

The output is still indexed and byte-identical on regen, because the step is deterministic and runs before indexed encoding.

- **Alternative — draw a solid base diamond under every terrain sprite in the renderer.** Rejected. That only hides the gap, and the tile edges still don't line up with the art.
- **Alternative — hand-edit the PNGs.** Rejected. The next regen would overwrite the edits.

### D8 — Terrain art is drawn locally by a procedural renderer, not by the image API

Catalog entries with front matter `source = "procedural"` are drawn by `scripts/generate_sprites_ai/procedural.py`:

- The renderer paints each sprite at its canonical 64×32 size using only `world.md` palette colours, with a fixed integer hash for noise.
- `render_sheet` upscales the sprite with nearest-neighbour to the 1024×1024 `_sheets/` image.
- The existing offline path (sheet → nearest downsample → quantize → indexed PNG) therefore reproduces the canonical pixels exactly, and `make sprites-verify` stays hermetic.
- `make sprites-procedural` (`--procedural`) redraws every procedural sheet and then regenerates all atlases offline. It needs no API key.
- The online pipeline never calls the API for procedural entries.

All five terrain entries (16 sprites) move to this source. The art is lit from the north-west with a dithered south rim, so the grid reads without hard lines. Water bands run along `x + 2y` with a 16-pixel period: neighbouring iso tiles shift `x + 2y` by 0 or 64, so the bands continue across seams.

- **Alternative — regenerate terrain with the image API and `two-pass: true`.** Rejected for this change. It needs a paid key that isn't available, and the API output is the source of the defects in the first place. Flat ground tiles are also exactly the kind of sprite a procedural renderer draws well. Buildings stay on the AI path.
- **Alternative — hand-draw the PNGs.** Rejected. Not reproducible, and a later `make sprites` run would overwrite them.

### D4 — Icons resolve through `SKTextureAtlas(named: "Icons")`

`GoodIconLoader`'s default resolver becomes an atlas resolver. It checks `atlas.textureNames.contains("good-<raw>")`, then bridges `texture.cgImage()` into `Image(decorative:scale:)` with `.interpolation(.none)`. The `Origin` enum gains `.atlas(name:)`, and URL injection stays available for tests.

- **Alternative — an asset catalog (`.xcassets`).** Rejected. The pipeline writes to `Icons.atlas/`, and CI verifies those bytes. A second copy in an asset catalog would drift.
- **Alternative — bundle `Icons.atlas` as a folder reference so the PNGs stay loose.** Rejected. It's fragile (Xcode may still compile anything named `*.atlas`), and SpriteKit can no longer share the atlas.

### D5 — The farm is a plain producer; the starter stock is rebalanced

`BuildingKind.farm` goes through the existing generic producer system: recipe `[] → [.food: 1]` every 40 ticks, a 2×2 footprint, $60, and 2 wood. It has no fertility or terrain requirement. Fertility is a candidate "surprise" mechanic for `add-historical-ages`.

The starter stock goes from 4 wood + 2 planks to 6 wood + 5 planks + 2 food. That covers lumberjack (2 wood) + farm (2 wood) + house (4 planks), plus the sawmill's 1 plank. A playthrough with 4 planks deadlocked: the house used every plank, and the material rule only queues a building on a missing good when the island already has a producer of that good, which the sawmill itself would be. With 5 planks, no other plank-costing building is affordable, so the last plank is always left for the sawmill.

Old saves keep their old starter stock. The stock is only seeded at world-gen, so no migration is needed.

- **Alternative — a fisher's hut on the shore.** Deferred. Shore placement adds an orientation sprite set (four directions × three states). The farm is the cheapest way to close the food loop.

**CityCore invariant:** the farm and starter changes are Foundation-only edits to `Building.swift`, `Production.swift`, and `World+Fixture.swift`. `check-no-apple-ui-imports.sh` keeps guarding this.

### D9 — The town center is a full goods buffer

There are three warehouse-only lists today:

- `goodsBuffers()`: carrier destinations, warehouses and ports;
- `findRoadConnectedWarehouse`: warehouses only;
- `hasGoodInReach`: house needs, warehouses only.

Placement costs already count the town center (`placementBufferKinds`). All three lookups now use one shared set, `logisticsBufferKinds = [.warehouse, .port, .townCenter]`. The shipyard stays out: it consumes its stock to build ships. The town center's capacity goes from 8 to 40, so the starter stock (12 units) fits with room for early production.

Carrier destination selection walks buildings sorted by `EntityID.raw` and only replaces the best candidate on a strictly shorter path. That gives the deterministic tie-break the spec has always required. The current code iterates a `Dictionary` in hash order, which Swift randomises per process.

- **Alternative — keep warehouse-only logistics and raise the starter stock to afford a warehouse (2 wood + 6 planks) up front.** Rejected. The player's first action would be a building they don't understand yet, and the town center would stay a dead box that holds goods nobody can use.
- **Alternative — add the town center only to `hasGoodInReach`.** Rejected. Production still wouldn't reach the city without a warehouse, and the opening loop stays broken.

**CityCore invariant:** pure data-structure edits in `World.swift`, `Systems.swift`, and `PortAndShipyard.swift`. No new imports.

### D10 — Building operational frames are derived from the base sprite

The AI pipeline draws each operational frame with its own API call, so each frame is a different drawing of the building. On the `e57823e` atlas the town center's two frames have different architecture, and the sawmill's four frames are four different houses. Because the renderer cycles only the operational frames, every swap makes the building jump and resize. Registering the frames onto one bounding box doesn't help: it removes the jump, but the building still turns into a different building.

Catalog entries with front matter `operational = "derived"` now build their `-operational-N` frames locally:

1. Process the base sheet (threshold, downsample, quantize) to the base's target size.
2. Keep that building pixel-identical.
3. Draw a chimney smoke plume above the roof that rises and drifts by one step per frame.

All eleven building entries with operational frames opt in. The sprite-animation spec keeps animating the same kinds; only the frames' content changes.

The content gate gains a `frame_misaligned` rule: an operational frame's left, right and bottom bounds must lie within 2 px of the base sprite's. The top is exempt so smoke can rise. The palette-coherence metric could not catch this defect, because the frames share a palette.

- **Alternative — stop animating AI-drawn buildings.** Rejected. It breaks the sprite-animation spec's "Operational sawmill animates" scenario, and the city looks dead.
- **Alternative — redraw the buildings procedurally.** Deferred. That's a bigger art pass, and a natural fit for the ages work, where every building needs per-age variants anyway.

### D6 — Rejection feedback lives in `HUDViewModel`, triggered by a `canPlace` check on tap

Until now, `GameSession.handleTap` enqueued `.place` without checking, and the simulation dropped rejected commands silently at the tick boundary. Now:

1. A tap with a build tool armed runs `world.canPlace` first.
2. On `.rejected(reason)`, the session calls `HUDViewModel.showRejection(_:now:)` and enqueues nothing.
3. The view model maps the reason to text (`PlacementRejectionText`) and stores the time it was shown.
4. `PlacementRejectionBanner` reads the message through a `TimelineView`, so it expires without a timer.

Drag-to-paint gets no feedback. Painting a road across existing road tiles would otherwise flood the banner with "Tile occupied".

- **Alternative — emit a `WorldEvent.placementRejected` from CityCore.** Rejected. A rejection never reaches the simulation once the session checks first, and routing UI feedback through the world would put it into deterministic state.

Two runtime findings shaped the implementation:

- The compiled `Icons.atlasc` lists texture names with the `.png` extension, so the icon lookup accepts both forms.
- The pan `DragGesture` cancelled the scene's touches, which broke drag-to-paint. It is now masked off while a build tool is armed.

### D7 — Compact labels use `lineLimit(1)` with `minimumScaleFactor(0.7)`

`PlatformLayout.compact` exposes a label configuration (line limit and minimum scale factor) that the HUD and palette views apply. Money is formatted with `IntegerFormatStyle.Currency` in the current locale.

- **Alternative — abbreviated money ("$1.0k").** Rejected for now. Exact money matters while early costs are $50–$80.

## Determinism

The farm recipe is a constant-table entry processed by the existing production system in its existing per-tick order (sorted by `EntityID`), so replay stays byte-identical. The starter stock is constant. Rejection feedback, icon loading, and layout are outside `World` entirely. Carrier routing now iterates buildings in `EntityID` order, and the footprint neighbour scans (`anyAdjacentRoad`, `clearAdjacentForest`) walk footprint tiles in row-major order instead of a `Set`. Both changes remove dependencies on per-process hash seeding: which road a building used and which forest tile a lumberjack cleared could differ between two runs of identical input, and `terrainGrid` is part of `World` equality. Previously carrier routing which removes a dependency on per-process `Dictionary` hash order that could already make equal-length routes diverge between runs. The DeterminismFixture is regenerated once, because new worlds now start with different stock and the town center now takes deliveries. That's an expected change, recorded in the fixture commit.

## Risks / Trade-offs

- **[Risk] The coherence threshold flags legitimate frames** (sawmill blade states, construction stages) → Mitigation: calibrate on the full current atlas before enabling the gate. Construction frames (`-constructing-N`) are compared against each other, not against the finished base, because a scaffold legitimately looks different.
- **[Risk] Diamond-fit stretches art with an odd aspect ratio** (beach-0 was a rectangle) → Mitigation: the gate runs after the step. Any sprite that still looks wrong is regenerated, not force-fitted.
- **[Risk] Regenerating sprites needs a paid API key, which CI doesn't have** → Mitigation: regen is a local step. CI stays hermetic (offline byte check plus the content gate) and rejects bad commits either way.
- **[Risk] Changing the starter stock invalidates balance assumptions in existing tests** → Mitigation: those tests use `World+Fixture`/`testMaterialCredits` rather than the starter stock. The tests that do rely on it are listed in tasks and updated in the same commit.
- **[Trade-off] The gate measures palette, not meaning.** A water-coloured house would still pass. That's acceptable: the playtest defects were all off-palette or empty.

## Migration Plan

No save migration. The order of work:

1. Land the gate, which is expected to fail on the current art.
2. Add diamond-fit and regenerate the art until the gate passes.
3. Land the farm and the starter stock.
4. Land the HUD fixes.

Each step is verified by running the app in the simulator (see `.claude/skills/verify/SKILL.md`).
