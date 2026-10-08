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

The gate is a small library (ImageIO/CoreGraphics decode plus three metric functions) with a thin `sprite-content-gate` executable. `make sprites-verify` runs it after the Python byte check with `xcrun swift run --package-path Packages/CityRender2D sprite-content-gate Resources`.

- **Alternative — Python, next to `postprocess.py`.** Rejected. Spec scenarios must map to Swift `@Test`s, so we'd need the metric in Python *and* Swift, and the two copies could disagree.
- **Alternative — a standalone `scripts/check-sprite-content.swift`.** Rejected. A script can't be unit-tested from `Packages/*/Tests`.
- **Placement:** CityRender2D already owns the atlas layout and naming grammar. Keeping the gate as a separate target means the app's `CityRender2D` library doesn't link it.

### D2 — Coherence metric: a 16-bin palette histogram, chi-squared distance

Opaque pixels are quantised into 4 luminance × 4 hue-sector bins and normalised. Frames are compared to the base sprite using chi-squared distance, with the threshold `coherence_max_distance` in `pipeline.toml`. The default is calibrated on the existing good frames (grass-0/1, beach) and must flag water-1 (a house) against the water base.

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

### D4 — Icons resolve through `SKTextureAtlas(named: "Icons")`

`GoodIconLoader`'s default resolver becomes an atlas resolver. It checks `atlas.textureNames.contains("good-<raw>")`, then bridges `texture.cgImage()` into `Image(decorative:scale:)` with `.interpolation(.none)`. The `Origin` enum gains `.atlas(name:)`, and URL injection stays available for tests.

- **Alternative — an asset catalog (`.xcassets`).** Rejected. The pipeline writes to `Icons.atlas/`, and CI verifies those bytes. A second copy in an asset catalog would drift.
- **Alternative — bundle `Icons.atlas` as a folder reference so the PNGs stay loose.** Rejected. It's fragile (Xcode may still compile anything named `*.atlas`), and SpriteKit can no longer share the atlas.

### D5 — The farm is a plain producer; the starter stock is rebalanced

`BuildingKind.farm` goes through the existing generic producer system: recipe `[] → [.food: 1]` every 40 ticks, a 2×2 footprint, $60, and 2 wood. It has no fertility or terrain requirement. Fertility is a candidate "surprise" mechanic for `add-historical-ages`.

The starter stock goes from 4 wood + 2 planks to 6 wood + 4 planks + 2 food. That covers lumberjack (2 wood) + farm (2 wood) + house (4 planks), with 2 wood to spare toward a sawmill.

Old saves keep their old starter stock. The stock is only seeded at world-gen, so no migration is needed.

- **Alternative — a fisher's hut on the shore.** Deferred. Shore placement adds an orientation sprite set (four directions × three states). The farm is the cheapest way to close the food loop.

**CityCore invariant:** the farm and starter changes are Foundation-only edits to `Building.swift`, `Production.swift`, and `World+Fixture.swift`. `check-no-apple-ui-imports.sh` keeps guarding this.

### D6 — Rejection feedback lives in `HUDViewModel`, driven by `GameSession`'s placement result

`GameSession` already calls `canPlace` before it enqueues a placement. When the result is `.rejected(reason)`, it forwards the reason to `HUDViewModel.showRejection(_:now:)`. The view model maps the reason to a message (`PlacementRejectionText`) and stores an expiry time. The view reads the message through `TimelineView`, so it expires without a timer.

- **Alternative — emit a `WorldEvent.placementRejected` from CityCore.** Rejected. A rejection never reaches the simulation, because the command is never enqueued. Routing it through the world would put UI feedback into deterministic state.

### D7 — Compact labels use `lineLimit(1)` with `minimumScaleFactor(0.7)`

`PlatformLayout.compact` exposes a label configuration (line limit and minimum scale factor) that the HUD and palette views apply. Money is formatted with `IntegerFormatStyle.Currency` in the current locale.

- **Alternative — abbreviated money ("$1.0k").** Rejected for now. Exact money matters while early costs are $50–$80.

## Determinism

The farm recipe is a constant-table entry processed by the existing production system in its existing per-tick order (sorted by `EntityID`), so replay stays byte-identical. The starter stock is constant. Rejection feedback, icon loading, and layout are outside `World` entirely. The DeterminismFixture is regenerated once, because new worlds now start with different stock. That's an expected change, recorded in the fixture commit.

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
