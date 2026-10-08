## 1. M1 — Sprite content gate

- [x] 1.1 Tests-first: translate `#### Scenario: Every committed terrain sprite fills the diamond`, `#### Scenario: Content gate rejects an under-filled terrain sprite`, `#### Scenario: Content gate rejects a fully transparent frame`, `#### Scenario: Content gate rejects a frame that depicts a different object`, and `#### Scenario: Content gate accepts coherent water frames` into failing tests in a new `SpriteContentGateTests` target. Fixture PNGs are generated in-test into a temp directory. Confirm red.
- [x] 1.2 Implement to green: add the `SpriteContentGate` library target and the `sprite-content-gate` executable to `Packages/CityRender2D/Package.swift`. Implement the diamond mask, the coverage and outside-ratio metrics, the empty-frame check, and the 16-bin chi-squared coherence check (design D1, D2). Compare construction frames against each other, not against the finished base.
- [x] 1.3 Calibrate `coherence_max_distance`: run the gate over the current atlases and record the distances for known-good frames (grass, beach, sawmill operational, construction stages) and known-bad frames (water-1, water.png, mountain-v1/v2). Pin a threshold between the two groups in `Resources/Sprites.style/pipeline.toml`.
- [x] 1.4 Tests-first: translate `#### Scenario: Verification fails on a content defect even when bytes reproduce` into a failing test that runs the gate executable against a temp atlas directory containing an empty frame. Confirm red.
- [x] 1.5 Implement to green: chain the gate into `make sprites-verify` after the Python byte check, printing one failure per line as `<file> <reason>`. Give the gate its own SwiftPM scratch path so the nested `make` call inside `swift test` doesn't deadlock on the build lock. Confirm the CI sprite job picks it up through the make target.
- [x] 1.6 Refactor under a green bar.
- [x] 1.7 Verify that `make test-scenarios` is clean for the M1 scenarios. The gate is expected to FAIL on the current committed art (that's the point); record the failure list in the M2 commit message.

## 2. M2 — Diamond-fit and art regeneration

- [x] 2.1 Tests-first (pytest, `scripts/tests/test_postprocess.py`): diamond-fit scales an under-filled 64×32 sprite to ≥90% coverage, clips it to the mask, and is byte-deterministic across two runs. Confirm red.
- [x] 2.2 Implement to green: add a `diamond_fit()` step to `postprocess.py` for `terrain-*` entries, running before indexed encoding (design D3).
- [x] 2.3 Redraw the terrain sprites locally (design D8): add `procedural.py` with pytest coverage, mark the five terrain catalog entries `source = "procedural"`, add `make sprites-procedural`, and run it.
- [x] 2.4 Run `make sprites-verify` until the byte check and the content gate both pass. Commit catalog, sheets, and atlas PNGs together.
- [x] 2.5 Runtime check: launch the iOS build in the simulator (per `.claude/skills/verify/SKILL.md`). Take screenshots of the full island at three moments ≥0.2 s apart and confirm the water never shows houses or turns empty, and no dark mesh shows between tiles.
- [x] 2.6 Refactor under a green bar.

## 3. M3 — Farm and starter stock

- [x] 3.1 Tests-first: translate `#### Scenario: Farm spec exposes its footprint and costs`, `#### Scenario: Farm produces food without inputs`, `#### Scenario: Farm food satisfies a connected house`, `#### Scenario: Fresh-world town center holds starter goods`, `#### Scenario: Starter goods are part of the island stockpile aggregate`, `#### Scenario: First lumberjack placement consumes starter wood`, and `#### Scenario: Starter goods afford a lumberjack, a farm, and a house`, `#### Scenario: Town center accepts carrier deposits`, `#### Scenario: Equidistant buffers tie-break on entity ID`, `#### Scenario: Town center food satisfies a connected house`, and `#### Scenario: Unconnected town center does not satisfy needs` into failing tests in `CityCoreTests`. Confirm red.
- [x] 3.2 Implement to green: add `BuildingKind.farm`, its `BuildingSpec`, its `ProductionCatalog` recipe, its stockpile capacity, and the new starter inventory in `seedTownCenters` (design D5). Update the tests that assert the old 4 wood + 2 planks stock in the same commit.
- [x] 3.2b Implement to green: make the town center a goods buffer with capacity 40 behind one shared `logisticsBufferKinds` set used by carrier destinations, buffer selection, and house needs. Iterate buffers in `EntityID` order and replace only on a strictly shorter path (design D9).
- [x] 3.3 Check the DeterminismFixture and the v1/v2 save fixtures for starter-stock dependencies. Result: no committed determinism output exists (CI compares fresh macOS and Linux runs), and the save fixtures don't encode starter stock. Also fixed two `Set`-ordered footprint scans that made replays diverge (design D9 determinism).
- [x] 3.4 Add the farm to the build palette, the sprite catalog (`catalog/building-farm.md` with `source = "procedural"`, constructing and operational frames), `procedural.py`, and `SpriteAnimation.entry(for:)`. Run `make sprites-procedural`.
- [ ] 3.5 Runtime check in the simulator: on a fresh Single Island seed 0 game, place a lumberjack, a farm, a house, and a road connecting them to the town center. Within 3 in-game minutes the HUD population should read above 0.
- [ ] 3.6 Refactor under a green bar.
- [ ] 3.7 Verify that `make test-scenarios` is clean for the M3 scenarios.

## 3b. M3b — Stable building animations

- [x] 3b.1 Tests-first: translate `#### Scenario: Content gate rejects a shifted operational frame` and `#### Scenario: Content gate accepts smoke above the roof` into failing tests in `SpriteContentGateTests`. Add pytest coverage for derived frames. Confirm red.
- [x] 3b.2 Implement to green: add the `frame_misaligned` gate rule, `procedural.derive_operational`, and `operational = "derived"` support in the batcher (design D10).
- [x] 3b.3 Mark all eleven building entries with operational frames as derived and run `make sprites-procedural`; `make sprites-verify` passes.
- [x] 3b.4 Runtime check in the simulator: operational buildings hold still and only the smoke moves.

## 4. M4 — HUD feedback, icons, compact layout

- [x] 4.1 Tests-first: translate `#### Scenario: Material shortfall message names the missing goods`, `#### Scenario: Occupied tile message`, `#### Scenario: Rejection message expires`, `#### Scenario: Bundled good icon resolves from the compiled atlas`, `#### Scenario: Missing good icon falls back to the symbol`, `#### Scenario: Compact money value uses grouped digits`, and `#### Scenario: Compact layout limits labels to one line` into failing tests in `CityUITests`. Confirm red.
- [x] 4.2 Implement to green: add `PlacementRejectionText` and `HUDViewModel.showRejection(_:now:)` with a 2.5 s expiry, and have `GameSession` forward rejected `canPlace` results (design D6).
- [x] 4.3 Implement to green: add an atlas resolver to `GoodIconLoader` and an `Origin.atlas(name:)` case (design D4).
- [x] 4.4 Implement to green: add the compact label configuration to `PlatformLayout` and grouped-digit money formatting. Apply both in the HUD and palette views (design D7).
- [x] 4.5 Runtime check in the simulator:
  - The HUD shows three distinct good icons.
  - "$1,000" sits on one line.
  - Palette labels don't wrap.
  - Placing a house with too few planks shows "Needs N more planks" and the message clears after about 2.5 s.
- [x] 4.6 Refactor under a green bar.
- [x] 4.7 Verify that `make test-scenarios` is clean for the M4 scenarios.

## 5. M5 — Tooling and final verification

- [ ] 5.1 Makefile: resolve `DESTINATION_IOS` to the first available iPhone simulator via `xcrun simctl list devices available`, falling back to an explicit `IOS_SIM` variable.
- [ ] 5.2 Final runtime pass: build both schemes, then play the iOS build for 5 in-game minutes from a new game (lumberjack → farm → house → sawmill → second house). Attach screenshots to the PR.
- [ ] 5.3 Mac runtime pass: launch the Mac build, place a farm with the mouse, and confirm the icons and rejection message match iOS — DEFERRED (requires interactive Mac session)
- [ ] 5.4 Run `make lint && make format`, then `openspec validate fix-playable-foundation --strict`.
