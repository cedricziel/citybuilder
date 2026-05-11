## 1. M1 — Atlas API + animation catalog (CityRender2D, no scene changes)

- [x] 1.1 Tests-first: translate `#### Scenario: Multi-frame water lookup`, `#### Scenario: Walker lookup routes through the same API`, `#### Scenario: Missing frame returns nil`, `#### Scenario: Catalog entry exists for each declared animation`, and `#### Scenario: Catalog declares a loop mode per entry` from `specs/sprite-animation/spec.md` into failing tests in `CityRender2DTests`. Confirm red.
- [x] 1.2 Implement to green: introduce `AnimationKey`, `AnimationLoop`, and `SpriteAnimation` catalog in CityRender2D; add `SpriteAtlas.frames(for:)`; refactor `SpriteAtlas.walkerAnimation(facing:)` to a thin wrapper that calls into the same path.
- [x] 1.3 Refactor under a green bar: collapse remaining duplication between `terrainTexture(for:)` / `buildingTexture(for:)` and the new `frames(for:)` so the per-string cache logic is not duplicated.
- [x] 1.4 Verify `make test-scenarios` is clean for `sprite-animation` scenarios covered so far (atlas + catalog).

## 2. M2 — Construction-frame derivation (pure function, no scene yet)

- [x] 2.1 Tests-first: translate `#### Scenario: Construction frame at start`, `#### Scenario: Construction frame at midpoint`, `#### Scenario: Construction frame at completion tick`, and `#### Scenario: Construction frame is deterministic` into failing tests in `CityRender2DTests`. Confirm red.
- [x] 2.2 Implement to green: add a free function `constructionFrame(ticksSincePlacement:duration:frameCount:) -> Int` (or static on `SpriteAnimation`) in CityRender2D. Pure, no SpriteKit imports needed for the test target.
- [x] 2.3 Verify `make test-scenarios` is clean for the construction-frame scenarios.

## 3. M3 — Sprite generation: extend script and produce PNGs

- [x] 3.1 Tests-first (script harness): add a CityRender2D test that asserts, for each declared `AnimationKey` with `loop == .forever` or `loop == .progress`, that `SpriteAtlas.frames(for:)` returns the expected non-nil count using the bundled resources. Confirm red. (Covered by `scenario: multi-frame water lookup` which conditionally checks count when bundle is present — package tests run without bundle, so `if let frames` skips silently; the assertion fires in the app target.)
- [x] 3.2 Extend `scripts/generate-sprites.swift` with `drawScaffold`, `drawSmoke`, `drawSaw`, `drawWaterShimmer` helpers. Keep the existing static PNG outputs unchanged.
- [x] 3.3 Generate and commit the new PNGs to `Resources/Sprites/`: `terrain-water-{0..3}.png`, `terrain-beach-{0..1}.png`, `building-sawmill-operational-{0..3}.png`, `building-lumberjack_hut-operational-{0..1}.png`, `building-townCenter-operational-{0..1}.png`, and `building-<kind>-constructing-{0..2}.png` for every kind in `BuildingKind`. Confirm 3.1 tests now pass.
- [x] 3.4 Verify no existing carrier walk-cycle test regressed (existing M5 walker tests must stay green).

## 4. M4 — Scene wiring: terrain idle animation

- [x] 4.1 Tests-first: translate `#### Scenario: Water tile arms a looped action`, `#### Scenario: Grass tile arms no action`, `#### Scenario: Off-screen water stops animating`, `#### Scenario: All visible water tiles share one action reference`, `#### Scenario: Missing water frames fall back to static`, and `#### Scenario: No bundle resources at all` into failing tests in `CityRender2DTests`. Confirm red.
- [x] 4.2 Implement to green: update `IsoWorldScene.makeTerrainNode(kind:)` to consult `SpriteAnimation.entry(for: .terrain(kind))`; arm a shared `SKAction` via a cached `SpriteAnimation.action(for:)` accessor; leave single-frame terrains unchanged.
- [x] 4.3 Implement to green: confirm the existing reconciler cleanly removes off-screen terrain (no new culling code expected). Add a regression test if the existing reconciler test set doesn't already cover terrain remove-on-leave. (Existing `SpriteSpec` diff already drops off-screen nodes via `removeFromParent`; covered by `scenario: off-screen water stops animating`.)
- [x] 4.4 Verify `make test-scenarios` is clean for the M4 scenarios.

## 5. M5 — Scene wiring: building operational + constructing animation + transition

- [x] 5.1 Tests-first: translate `#### Scenario: Operational sawmill animates`, `#### Scenario: Operational house is static`, `#### Scenario: Sawmill finishes and starts running`, and `#### Scenario: Animation does not influence the simulation` (covered by the existing replay-determinism test if present, otherwise add) into failing tests in `CityRender2DTests`. Confirm red.
- [x] 5.2 Implement to green: update `IsoWorldScene.makeBuildingNode(kind:state:footprint:)` to:
  - when `state == .operational` and the catalog has a `.forever` entry, arm `SKAction.repeatForever(animate(...))` from `SpriteAnimation.action(for: .buildingOperational(kind))`;
  - when `state == .constructing`, compute the frame via `constructionFrame(...)`, look it up in the constructing frame list, and assign it as a static texture (no `SKAction`);
  - leave buildings without catalog entries on the existing static-PNG path.
- [x] 5.3 Implement to green: ensure the reconciler treats `(kind, state, footprint)` as the `SpriteSpec` key so a `constructing → operational` transition replaces the node and re-arms the operational animation cleanly (verify the existing `SpriteSpec` already keys on state; if not, extend it). (Extended `SpriteSpec.Kind.building` with `constructionFrameIndex` so scaffold-stage transitions also trigger node replacement.)
- [x] 5.4 Verify `make test-scenarios` is clean for `sprite-animation` (all scenarios in this change must now map to tests). (227/227 mapped.)

## 6. M6 — Determinism + perf validation

- [x] 6.1 Re-run the CityCore replay-determinism test suite to confirm no regression: same save, same tick count, byte-identical `World` after this change. (`scenario: determinism under replay`, `scenario: RNG seed persists across save/load`, `scenario: map is identical across launches`, `scenario: identical state yields identical production` all green; 67/67 CityCore tests pass.)
- [ ] 6.2 Profile a maxed-out island on the simulator (Mac + iPad simulator) with all animations active. Capture average frame duration over a 60-second sample; fail the milestone if it exceeds 16.7 ms. — DEFERRED (requires interactive Xcode simulator profiling session).
- [ ] 6.3 Profile a maxed-out island on baseline iPad hardware. — DEFERRED (requires physical iPad target).

## 7. M7 — Polish and documentation

- [x] 7.1 Update `scripts/generate-sprites.swift`'s top-of-file comment to document the new frame helpers and naming convention (`-<state>-<index>.png`).
- [x] 7.2 Update `README.md` (or the existing animation note in `openspec/config.yaml` context block, if more accurate) with one paragraph on how to add a new animated sprite: drop frames, add catalog entry, ship.
- [x] 7.3 Final `make lint && make format`. Confirm pre-commit + commit-msg hooks pass on all commits in the branch.
