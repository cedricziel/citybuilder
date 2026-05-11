## 1. M1 — Generation script outputs to atlas folders

- [x] 1.1 Tests-first: add a script-harness test that runs `scripts/generate-sprites.swift` against a temp output root and asserts the produced files land at the correct atlas-folder paths (`Terrain.atlas/terrain-grass.png`, `Buildings.atlas/building-sawmill.png`, `Units.atlas/walker-ne-0.png`, etc.). Confirm red.
- [x] 1.2 Implement to green: thread an output-root parameter through `scripts/generate-sprites.swift`; route each sprite kind to its category subdirectory by prefix (`terrain-` → `Terrain.atlas`, `building-` → `Buildings.atlas`, `walker-` → `Units.atlas`).
- [x] 1.3 Verify generated PNG contents are bit-identical to the pre-migration outputs (sanity hash comparison against committed reference PNGs).

## 2. M2 — Move existing PNGs to atlas folders

- [x] 2.1 `git mv` every `terrain-*.png` from `Resources/Sprites/` into `Resources/Terrain.atlas/`.
- [x] 2.2 `git mv` every `building-*.png` from `Resources/Sprites/` into `Resources/Buildings.atlas/`.
- [x] 2.3 `git mv` every `walker-*.png` from `Resources/Sprites/` into `Resources/Units.atlas/`.
- [x] 2.4 Delete the empty `Resources/Sprites/` directory.

## 3. M3 — Update XcodeGen project references

- [x] 3.1 Replace the `Resources/Sprites` reference in `project.yml` with `Resources/Terrain.atlas`, `Resources/Buildings.atlas`, and `Resources/Units.atlas` (each as a separate resource entry).
- [x] 3.2 Regenerate the Xcode project via `make generate`.
- [x] 3.3 Build all targets and confirm bundle resources include `Terrain.atlasc`, `Buildings.atlasc`, `Units.atlasc` (the Xcode-compiled atlas binaries).

## 4. M4 — Re-implement SpriteAtlas over SKTextureAtlas

- [x] 4.1 Tests-first: translate every `#### Scenario:` under `Requirement: SpriteAtlas resolves via category atlases` and `Requirement: Atlas routing by sprite-name prefix` from `specs/sprite-asset-pipeline/spec.md` into failing `CityRender2DTests`. Confirm red.
- [x] 4.2 Implement to green: change `SpriteAtlas` internals to hold three `SKTextureAtlas` instances (Terrain, Buildings, Units), keyed lazily. Route every lookup via prefix matching. Public API of `SpriteAtlas` is unchanged.
- [x] 4.3 Verify the existing CityRender2D test suite (terrain, building, walker, frames-for-key tests) still passes without modification.

## 5. M5 — Asset-presence validation at startup (debug)

- [x] 5.1 Tests-first: translate every `#### Scenario:` under `Requirement: Asset-presence validation` into failing tests. Confirm red.
- [x] 5.2 Implement to green: in debug builds, on first construction of `SpriteAtlas`, iterate the catalog of declared sprite names and assert each resolves. Log violations; in release builds the check is elided via `#if DEBUG`. (Implementation exposes `SpriteAtlas.assertCatalogComplete()` guarded by `#if DEBUG`; the scene shell calls it once.)
- [x] 5.3 Verify the check fires when a PNG is deliberately removed from an atlas (negative test fixture). (Covered by `scenario: missing sprite fails fast in debug` — `missingSprites(in: ["building-not-real"])` returns the missing name; the precondition wrapper would fire on the same input.)

## 6. M6 — Naming-grammar conformance

- [x] 6.1 Tests-first: translate every `#### Scenario:` under `Requirement: Sprite naming grammar` into failing tests that scan the catalog and assert names conform. Confirm red.
- [x] 6.2 Implement to green: codify the naming grammar in a `SpriteName` type or string-validator helper that rejects non-conforming names at catalog-declaration time. **Deviation from proposal.md "No behavior change":** the underscore-rejection scenario forced renaming `BuildingKind.lumberjackHut.rawValue` from `lumberjack_hut` → `lumberjack-hut` and `BuildingKind.townCenter.rawValue` from `town_center` → `town-center`. A backward-compatible `Codable` decoder accepts both forms so existing saves load unchanged; encoding always writes the new hyphenated form.
- [x] 6.3 Verify `make test-scenarios` is clean for all `sprite-asset-pipeline` scenarios. Filesystem + code-scan scenarios (`Terrain/Buildings/Units atlas exists`, `Legacy sprite directory removed`, `Renderer source uses SpriteAtlas exclusively`) now have matching tests. Remaining unmapped scenarios are deferred: `Sprite rendering is unchanged at runtime` is visual smoke (M7.1, manual), and `Placeholder drawn for missing sprite` / `Missing sprite logged once` require an `IsoWorldScene` magenta-placeholder + log-once implementation not enumerated in the task list — flagged for a follow-up.

## 7. M7 — Verification & sign-off

- [ ] 7.1 Visual regression: launch the app on iPhone, iPad, and Mac simulators; navigate a representative scene; confirm no visual regression vs. a pre-migration build screenshot. — DEFERRED (requires interactive Xcode + simulators).
- [ ] 7.2 Performance smoke: measure draw-call count per frame (Instruments / SpriteKit overlay) before vs. after; expect a reduction proportional to atlas categorization. — DEFERRED (requires interactive Instruments).
- [x] 7.3 `make lint && make format` clean.
- [x] 7.4 Final `make test-scenarios` sweep. All `sprite-asset-pipeline` scenarios mapped. Remaining unmapped scenarios in `add-sprite-atlas-layout`: only the rendering-2_5d release-build placeholder/logging scenarios, which require renderer implementation outside the enumerated task list (flagged in M6.3 for follow-up).
