> **TDD policy (design D13).** Every implementation task below is implicitly red-green-refactor: translate the relevant `#### Scenario:` blocks from `specs/<capability>/spec.md` into failing `swift-testing` tests first, then write the smallest production code to make them green, then refactor under a green bar. Where a task says "implement capability X", read it as "tests-first for capability X". Coverage gates and diff-cover enforcement are wired into CI in M0.

## 1. M0 — Repo scaffold (XcodeGen), packages, TDD plumbing, and SpriteKit "hello iso" spike

- [x] 1.1 Initialize git repo at `/Users/cedricziel/private/code/citybuilder`; add a `.gitignore` that excludes `*.xcodeproj`, `*.xcworkspace`, `.build/`, `DerivedData/`, and Xcode user data
- [x] 1.2 Add a `Makefile` with targets `generate` (runs `xcodegen generate`), `build`, `test`, `lint` (SwiftLint strict), `format` (SwiftFormat), and `hooks` (installs pre-commit hooks); document `brew install xcodegen pre-commit swiftlint swiftformat` in the README
- [x] 1.3 Author `.pre-commit-config.yaml` with pinned versions for: `swiftformat`, `swiftlint` (strict), `check-yaml`, `end-of-file-fixer`, `trailing-whitespace`, `check-merge-conflict`, `check-added-large-files` (1 MB threshold), a local hook `forbid-xcodeproj` blocking staged `.xcodeproj`/`.xcworkspace`, and `conventional-pre-commit` on `commit-msg`
- [x] 1.4 Author `.swiftlint.yml` and `.swiftformat` config files at repo root with project-wide rules; commit baseline configs that pass on an empty repo
- [x] 1.5 Run `make hooks` to install `pre-commit`, `commit-msg`, and `pre-push` hooks locally; the `pre-push` hook MUST run `swift test --package-path Packages/CityCore` and refuse the push on failure; verify `pre-commit run --all-files` passes on an empty repo
- [x] 1.6 Author `project.yml` at repo root declaring the workspace, app targets `CitybuilderiOS` (iPhone + iPad universal idiom) and `CitybuilderMac` (native macOS), an `citybuilder-cli` executable target, and local Swift package references
- [x] 1.7 In `project.yml`, set bundle identifier `com.cedricziel.citybuilder` on both app targets via a shared YAML anchor; add iCloud entitlement targeting CloudKit container `iCloud.com.cedricziel.citybuilder`; enable Universal Purchase
- [x] 1.8 Run `make generate`; verify both app schemes build empty SwiftUI lifecycle apps on their respective platforms
- [x] 1.9 Create empty Swift packages `CityCore`, `CityPersistence`, `CityUI`, `CityRender2D`, `CityRender3D` under `Packages/` and wire them as local package references in `project.yml`
- [x] 1.10 Configure `CityCore` package manifest to forbid Apple UI framework imports; add a `swift-testing` test target with coverage instrumentation enabled; commit one canary test that asserts a deliberately failing precondition, then delete it after verifying the failing-test path works locally and in CI
- [x] 1.11 Add `scripts/check-scenario-coverage.swift`: parses `openspec/changes/*/specs/**/*.md` for `#### Scenario:` headers, maps each to an expected `swift-testing` test name (`Scenario: foo bar` → `@Test("scenario: foo bar")`), and reports unmapped scenarios. Wire it into `make test-scenarios`.
- [x] 1.12 Add coverage tooling (`xccov` JSON export or `slather`) and a `scripts/check-coverage.sh` that enforces `CityCore` line coverage ≥ 80% and branch coverage ≥ 70%, and runs `--diff-cover` (compare against `main`) to fail when changed lines in `CityCore` lack coverage. Wire into `make test-coverage`.
- [ ] 1.13 Add a CI workflow (GitHub Actions or equivalent) that installs XcodeGen + pre-commit + SwiftLint + SwiftFormat, runs `pre-commit run --all-files`, runs `make generate`, builds all three targets, runs all `swift-testing` suites, and enforces `make test-coverage` and `make test-scenarios`; the workflow MUST gate merges to main
- [ ] 1.14 Build a throwaway "hello iso" SpriteKit scene in `CityRender2D`: 50×50 iso grid, pan/zoom camera, one sprite type. Embed it in both app targets via `SpriteView`. (Renderer spike is exempt from coverage gates while marked `// MARK: SPIKE` — must be deleted or rewritten test-first before M2.)
- [ ] 1.15 Confirm 60 fps on iPad and Mac; capture a baseline profile

## 2. M1 — `CityCore` simulation skeleton

- [ ] 2.1 Tests-first: translate every `#### Scenario:` from `specs/simulation-core/spec.md` and `specs/world-terrain/spec.md` into failing `swift-testing` tests in `CityCoreTests`. Confirm `make test` is red.
- [ ] 2.2 Implement to green: `EntityID`, dense component storage, and a fully `Codable` `World` struct
- [ ] 2.3 Implement to green: `Tick` loop at fixed 100 ms with seeded RNG persisted in `World`
- [ ] 2.4 Implement to green: `Command` enum and an input queue applied at tick boundaries
- [ ] 2.5 Implement to green: `world-terrain` capability — fixed island generator, `TerrainType` enum, `canPlace`, integer tile coordinates
- [ ] 2.6 Refactor under a green bar; verify all simulation-core and world-terrain scenarios map to passing tests via `make test-scenarios`
- [ ] 2.7 Add a `citybuilder-cli` executable target that loads a save, advances N ticks, and prints summary state; cover the CLI with an integration test that drives a known-good save through N ticks and asserts the resulting summary
- [ ] 2.8 Confirm `CityCore` line coverage ≥ 80% and branch coverage ≥ 70%; investigate and either test or justify any uncovered lines

## 3. M2 — Render the simulation; first interaction

- [ ] 3.1 Tests-first: translate every `#### Scenario:` from `specs/rendering-2_5d/spec.md` that does not require a live SpriteKit scene into pure tests in `CityRender2DTests` — iso projection math, culling math (in/out of view), input-intent translation, snapshot diffing for node reconciliation. Confirm red.
- [ ] 3.2 Implement to green: `WorldSnapshot` value type and a snapshot extraction method on `World` (with round-trip tests in `CityCoreTests`)
- [ ] 3.3 Implement to green: snapshot-driven renderer in `CityRender2D` that replaces the hello-iso spike; delete the spike or rewrite test-first
- [ ] 3.4 Implement to green: visible-tile culling with margin (math-tested; integration assertion confirms off-screen sprites absent from the scene tree)
- [ ] 3.5 Tests-first then implement: camera state persisted on `World` so it restores on load — scenario already in spec
- [ ] 3.6 Build `CityUI` first views: HUD frame with money + population placeholders, build palette stub. View-model logic MUST be tested headlessly via `swift-testing`; visual snapshot tests are deferred per D13.
- [ ] 3.7 Tests-first then implement: input mapping in `CityRender2D` that dispatches tap/drag/pinch/pan as `Intent` to a controller; the intent translation is pure and fully unit-tested
- [ ] 3.8 Implement placement of a single hardcoded building type via the build palette and a `place` command, with an integration test that drives `place` through the command queue and asserts the resulting snapshot

## 4. M3 — Buildings, roads, warehouses (the gameplay backbone)

- [ ] 4.1 Tests-first: translate every `#### Scenario:` from `specs/buildings-and-construction/spec.md`, `specs/road-network/spec.md`, and the non-carrier portions of `specs/warehouses-and-logistics/spec.md` into failing tests in `CityCoreTests`. Confirm red.
- [ ] 4.2 Implement to green: `buildings-and-construction` — catalog, footprints, construction state machine, demolition, build cost deduction
- [ ] 4.3 Implement to green: `road-network` — road tile placement, incrementally-maintained road graph, connectivity query, A* pathfinding with cache invalidation
- [ ] 4.4 Implement to green: warehouse storage, deposit/withdraw API, capacity enforcement (the non-carrier portion of `warehouses-and-logistics`)
- [ ] 4.5 Refactor under a green bar; verify `make test-scenarios` reports zero unmapped scenarios for these three capabilities
- [ ] 4.6 Add SpriteKit rendering for buildings and roads using snapshot-driven node reconciliation (reconciliation logic itself is unit-tested at the snapshot level, not via the scene tree)
- [ ] 4.7 Add inspector panel in `CityUI` that shows building details on tap/click; view-model logic tested headlessly
- [ ] 4.8 Confirm `CityCore` coverage floors hold; diff-cover green on the PR

## 5. M4 — Production chain, carriers, population, economy

- [ ] 5.1 Tests-first: translate every `#### Scenario:` from `specs/goods-and-production/spec.md`, the carrier portions of `specs/warehouses-and-logistics/spec.md`, `specs/population-and-needs/spec.md`, and `specs/economy/spec.md` into failing tests in `CityCoreTests`. Add scenario-driven tests for stalls, full stockpiles, broken paths, bankruptcy timer. Confirm red.
- [ ] 5.2 Implement to green: `goods-and-production` — goods catalog (wood, planks, food), producer behavior with input/output stockpiles, the Wood → Planks chain
- [ ] 5.3 Implement to green: carrier entities — spawn rules, movement along paths, deposit on arrival, recovery on broken paths, per-producer carrier cap
- [ ] 5.4 Implement to green: `population-and-needs` — houses, per-pop needs (food, plank upkeep), growth/decline, satisfaction tracking
- [ ] 5.5 Implement to green: `economy` — starting balance, build cost deduction, tax interval, upkeep deduction, bankruptcy grace period
- [ ] 5.6 Refactor under a green bar; verify `make test-scenarios` is clean for these four capabilities
- [ ] 5.7 Implement frame interpolation for carrier sprites between ticks (interpolation math unit-tested)
- [ ] 5.8 Add HUD bindings for money and population aggregate driven by snapshot diffing; view-model logic tested headlessly
- [ ] 5.9 Add a `citybuilder-cli` regression scenario: load a fixture save, advance 6000 ticks (10 sim-minutes), assert money, population, and warehouse totals match recorded baseline. This becomes a long-running smoke test for the whole sim.

## 6. M5 — Persistence and iCloud sync

- [ ] 6.1 Tests-first: translate every `#### Scenario:` from `specs/persistence-save-load/spec.md` into failing tests in `CityPersistenceTests`, including a crash-mid-write fault-injection test (using a fake `FileWriter` that throws between temp write and rename). Confirm red.
- [ ] 6.2 Implement to green: `persistence-save-load` — JSON Codable snapshot, atomic write via temp + rename, version field, save path resolution, autosave hooks (background + interval), integrity checks, migration framework that no-ops at v1
- [ ] 6.3 Add Save / Save As / Load / New Game flows in `CityUI` for all idioms; view-model logic tested headlessly
- [ ] 6.4 Tests-first (CloudKit): translate every `#### Scenario:` from `specs/icloud-sync/spec.md` into failing tests in `CityPersistenceTests`. Use a `CloudKitClient` protocol with an in-memory fake for fast tests; gate real-CloudKit tests behind `CITYBUILDER_CLOUDKIT_TESTS=1`. Confirm red.
- [ ] 6.5 Implement to green: `icloud-sync` against container `iCloud.com.cedricziel.citybuilder` — `CKRecord` schema with `CKAsset` body, upload triggers, pull on launch, LWW with overwrite prompt, `currentDevice` nudge, one-session local backup of replaced saves, offline and no-iCloud-account fallbacks
- [ ] 6.6 Refactor under a green bar; verify `make test-scenarios` clean for both capabilities
- [ ] 6.7 Run gated CloudKit suite against a developer iCloud account once before merge; record results in PR

## 7. M6 — Mac polish

- [ ] 7.1 Tests-first: translate Mac-relevant scenarios from `specs/platform-shells/spec.md` (hotkey pause, hover tooltip, menu bar, window resize relayout) into failing view-model / controller tests where logic is headless-testable. Confirm red.
- [ ] 7.2 Implement to green: Mac keyboard hotkeys for primary actions (pause, save, load, build menu, road tool, demolish tool, camera)
- [ ] 7.3 Implement to green: hover tooltips on Mac and iPad-with-pointer for tiles and buildings (tooltip selection logic is a pure function of hover target + delay state, fully unit-tested)
- [ ] 7.4 Implement to green: macOS menu bar commands mirroring HUD primary actions
- [ ] 7.5 Verify window resize relayouts HUD within one frame; verify fullscreen behavior

## 8. M7 — iPhone compact play

- [ ] 8.1 Tests-first: translate iPhone-relevant scenarios from `specs/platform-shells/spec.md` (compact HUD, default zoom, collapsed categories) into view-model tests asserting adaptive layout decisions for the `compact` size class. Confirm red.
- [ ] 8.2 Implement to green: iPhone-specific adaptive layout for HUD and build palette (bottom-sheet palette, collapsed categories)
- [ ] 8.3 Implement to green: tuned default zoom and camera bounds for iPhone screen
- [ ] 8.4 Implement to green: advanced controls hidden behind a "More" menu while keeping all functionality reachable
- [ ] 8.5 Validate full gameplay on iPhone with a maxed-out MVP island; capture performance baseline

## 9. M8 — 3D building portraits (optional polish)

- [ ] 9.1 Tests-first: translate every `#### Scenario:` from `specs/building-portraits-3d/spec.md` into headless tests of the inspector view-model (affordance shown only when USDZ exists, rotation math, lifecycle of load/unload). Confirm red.
- [ ] 9.2 Implement to green: `building-portraits-3d` — SceneView-based overlay sheet, USDZ loading per building, drag-to-rotate and pinch-to-zoom
- [ ] 9.3 Implement to green: "View in 3D" affordance to inspector when a USDZ asset is declared for the building
- [ ] 9.4 Verify lazy load and memory release on dismiss with Instruments (manual verification; record in PR)
- [ ] 9.5 Add an automated check that the simulation tick count under the overlay matches expected ticks for elapsed time (covers the "simulation continues during portrait" scenario)

## 10. Continuity, Handoff, and Apple Pencil

- [ ] 10.1 Adopt `NSUserActivity` for the current game so Handoff advertises it across devices
- [ ] 10.2 Implement Apple Pencil hover preview for placement on supported iPads
- [ ] 10.3 Validate Handoff across iPhone, iPad, Mac with the same Apple ID

## 11. Performance and quality gates

- [ ] 11.1 Add per-tick wall-clock instrumentation in `CityCore` and a debug overlay in `CityRender2D` that surfaces it; assert the budget (< 5 ms per tick on baseline iPhone for a maxed-out fixture island) with a `swift-testing` performance test that fails CI on regression
- [ ] 11.2 Tune carrier caps, A* heuristic, and warehouse selection so tick stays under 5 ms on baseline iPhone with maxed-out island
- [ ] 11.3 Tune renderer culling, batching, and interpolation so frame time stays under 16.7 ms on baseline iPad with maxed-out island; record frame-time samples and assert P95 ≤ 16.7 ms in a manual perf test gate
- [ ] 11.4 Audit `make test-scenarios` end-to-end: every `#### Scenario:` in `specs/**/*.md` MUST map to at least one passing test. Treat unmapped scenarios as hard failures from this point on.
- [ ] 11.5 Run a full end-to-end playthrough on all three platforms; capture screenshots and a profile

## 12. Release preparation

- [ ] 12.1 Author App Store metadata for all three platforms; verify Universal Purchase visibility
- [ ] 12.2 Configure CloudKit production schema (record types, fields) on container `iCloud.com.cedricziel.citybuilder` matching the development environment
- [ ] 12.3 Confirm save-format `version` is 1 and migration framework round-trips a v1 save
- [ ] 12.4 Write release notes and an MVP scope statement
- [ ] 12.5 Submit to TestFlight for internal validation
