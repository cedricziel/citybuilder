## Context

Greenfield Apple-exclusive city-builder. No existing code. Team is solo, with no prior experience shipping games on Apple's stack but comfortable with Swift and conventional commits. The MVP is ambitious in surface area (universal iPhone/iPad/Mac, deep simulation, iCloud sync) but conservative in tech choices (boring, shippable Apple frameworks only). The simulation must feel like Anno — carriers physically walk roads, production chains have inputs/outputs, population has needs — while the rendering is 2.5D isometric with optional 3D building portrait moments.

Hard constraints:
- Apple ecosystem only (Swift, Xcode, SwiftUI, SpriteKit, SceneKit, CloudKit).
- No third-party runtime libraries in MVP.
- Universal app: one codebase, three app targets (iOS, iPadOS via iOS target, macOS).
- Save format must survive across versions; CloudKit schema cannot churn cheaply.
- Simulation must be testable headlessly, fast, and deterministic.

## Goals / Non-Goals

**Goals:**
- A clean separation between simulation, rendering, persistence, and platform UI so that any one layer can be replaced or evolved without rewriting the others.
- A deterministic, snapshot-based simulation tick that supports save/load, deterministic replay-style tests, and trivial diffing.
- A 2.5D isometric world that holds 60 fps on a baseline iPad through an MVP-sized island, with input gestures that feel native on touch, pointer, and Apple Pencil.
- A save/sync model that survives multi-device usage without silently nuking work, even if conflict resolution is rough in v0.
- Authoring ergonomics: a developer can iterate on simulation logic without launching a simulator, can write content (buildings, goods) declaratively, and can profile every tick.
- A path to incremental polish (3D portraits, Mac hotkeys, iPhone companion mode) without architectural revolts.

**Non-Goals:**
- Free 3D world camera (Flavor C) — explicitly excluded; would double art cost.
- Multiplayer, SharePlay, or co-op in MVP.
- Multiple islands, scenarios, campaign, or trading with NPC factions in MVP.
- Modding API, content packs, or asset hot-reload in MVP.
- Vision Pro / visionOS support in MVP (architecture stays friendly, but no target ships).
- Game Center achievements/leaderboards in MVP.
- Cross-platform port (Linux/Windows) — but `CityCore` will not foreclose it.

## Decisions

### D1. Layered architecture with framework-free simulation core

```
+--------------------------------------------------------------+
|  App targets:  CitybuilderiOS  CitybuilderMac  (Universal)   |
+--------------------------------------------------------------+
|  CityUI         (SwiftUI: HUD, palette, inspectors, menus)   |
+--------------------------------------------------------------+
|  CityRender2D (SpriteKit)   |  CityRender3D (SceneKit)       |
+--------------------------------------------------------------+
|  CityPersistence (file I/O + CloudKit)                       |
+--------------------------------------------------------------+
|  CityCore       (pure Swift simulation, Codable, no Apple    |
|                  framework imports beyond Foundation)        |
+--------------------------------------------------------------+
```

Each layer is a Swift Package in the workspace. Higher layers depend on lower ones only. `CityCore` has zero Apple-UI dependencies and compiles on Linux.

**Why over alternatives:**
- *Monolithic app target*: faster to start, but couples sim to renderer, kills headless testing, makes the universal story painful.
- *One package, multiple products*: tempting, but separate packages make dependency boundaries enforceable by the compiler.
- *GameplayKit / SpriteKit-native ECS*: tightly couples to Apple's frameworks, complicates testing, and GameplayKit feels stagnant.

### D2. Deterministic fixed-tick simulation at 10 Hz, render-interpolated

Simulation advances in discrete 100 ms ticks. Render layer interpolates positions visually at display refresh rate. RNG is seeded per save. All inputs (player commands) are queued, applied at the next tick boundary.

**Why:**
- Determinism is the secret weapon for save/load, conflict diffing, and bug reproduction.
- 10 Hz is plenty for Anno-style economy; saves CPU on iPhone.
- Decoupling sim tick from render frame avoids the "frame-rate-dependent gameplay" trap.

**Alternatives considered:** continuous time with delta-t accumulation (rejected: harder to test, harder to serialize). 60 Hz tick (rejected: needlessly expensive for a non-twitch game).

### D3. ECS-light, struct-of-arrays component storage

`CityCore` stores entities as opaque `EntityID` integers. Components are stored in dense arrays keyed by entity. Systems are pure functions: `(World, inout WorldDelta) -> Void`. No protocol-witness dispatch in the hot path.

**Why:**
- Cache-friendly for tick-time loops over thousands of entities.
- Easy to snapshot: the entire `World` is `Codable`.
- No dependency on a third-party ECS library; rolled in ~200–400 lines.

**Alternatives:** GKEntity/GKComponent (couples to GameplayKit), reference-type "actor" entities (slower, scattered allocations), full third-party ECS (over-engineering for MVP).

### D4. Rendering = SpriteKit world + SceneKit portrait overlays + SwiftUI HUD

- The world is rendered by a single `SpriteKit` scene embedded via `SpriteView`. Tiles are `SKSpriteNode`s drawn in iso projection. The scene receives a `WorldSnapshot` each render frame and reconciles its node tree.
- `SKTileMapNode` is explicitly NOT used; it is too rigid for variable building footprints and isometric layering.
- HUD, build palette, inspector panels are SwiftUI views drawn over `SpriteView`.
- Building portraits are a SwiftUI overlay sheet containing a `SceneView` with a USDZ model.

**Why:** SwiftUI is the most learnable shell, SpriteKit is the most boring/shippable 2D renderer on Apple, SceneKit is the lightest 3D option for static model previews. RealityKit was considered for portraits but its non-AR composition story is rougher than SceneKit's.

### D5. Carriers physically walk roads (deep simulation)

Goods do not teleport. Each producer building, when it has output to ship, emits a carrier entity that pathfinds (A*) over the road graph to the nearest warehouse with capacity. Each consumer pulls from warehouses by emitting its own carrier. Road capacity, carrier speed, and warehouse range are tunable.

**Why:** This is the Anno feel the user explicitly chose ("deep simulation"). It makes the road network gameplay-relevant rather than cosmetic.

**Trade-off:** Significantly more sim cost and more visual entities to render. Mitigated by the 10 Hz tick and by aggressively culling off-screen carrier sprites.

### D6. Save = JSON snapshot in v0, binary later; one file per game

The entire `World` Codable encodes to a single JSON file in `~/Library/Application Support/Citybuilder/saves/<gameID>.json`. Atomic write via temp file + rename. JSON is chosen for v0 because it is human-debuggable; a binary encoding (likely `BinaryEncoder` or a hand-rolled format) is a later optimization. A `version` field at the root governs migrations.

**Why over alternatives:**
- *SwiftData / Core Data + NSPersistentCloudKitContainer*: tempting because of automatic CloudKit sync, but a game save is a snapshot, not a relational object graph. The impedance mismatch creates more problems than it solves, and CloudKit schema migration in SwiftData is painful.
- *Per-system files*: optimization for later; not needed at MVP island size.

### D7. iCloud sync = CKAsset blob in private DB, LWW v0

The save file is uploaded as a `CKAsset` inside a single `CKRecord` per game. Sync triggers: on app entering background, on explicit "Save & Sync" tap, and on launch (pull latest). Conflict policy in v0 is last-write-wins by `modificationDate`, with a visible warning if the local save is newer than CloudKit's at upload time.

A `currentDevice` field on the record indicates the device most recently editing; opening the game on a second device shows "This game is open on iPad — continue here?" before allowing edits. This is not a true lock; it is a UX nudge to prevent accidental divergence.

**Why over alternatives:**
- *Per-record sync of game entities*: would enable real merge but requires CRDT-like thinking far beyond MVP scope.
- *CloudKit shared DB*: only useful for multiplayer, not needed.
- *Manual iCloud Drive file sync*: less reliable for app-coupled data and gives worse offline behavior.

### D8. Platform shells: three shells, one shared UI package

`CityUI` is a Swift package of platform-agnostic SwiftUI views (HUD, palette, inspector). App targets compose them with platform-specific chrome:
- **iOS app target** (iPhone + iPad via universal idiom): touch-first, sheets for inspectors, big tap targets. iPad gets a sidebar layout; iPhone gets a tab/compact layout.
- **macOS app target**: keyboard hotkeys, hover tooltips, multiple windows allowed, pointer-driven build placement, menu bar commands.

iPhone is a full game but defaults to a "compact" layout that hides advanced UI; this is treated as a UX variant, not a gameplay variant.

### D9. Asset authoring: declarative Swift catalogs in v0, file-based later

Buildings, goods, and recipes are defined as `let` constants in Swift inside `CityCore` for MVP. This makes iteration fast (compile, run) and gives compile-time validation. Switching to JSON/Tiled or YAML content packs is a post-MVP capability.

### D10. App identifier and CloudKit container

The app SHALL ship under bundle identifier `com.cedricziel.citybuilder`, shared by both the iOS and macOS app targets to enable Universal Purchase. CloudKit operations target the matching private database container `iCloud.com.cedricziel.citybuilder`. Any future expansions (companion widgets, share extensions) MUST use suffixed identifiers (e.g. `com.cedricziel.citybuilder.<suffix>`) rather than divergent prefixes.

### D11. Project generation via XcodeGen

The Xcode project and workspace SHALL be generated from a `project.yml` at the repo root using [XcodeGen](https://github.com/yonaskolb/XcodeGen). The generated `.xcodeproj` (and `.xcworkspace`, if any) MUST be gitignored; only `project.yml` is the source of truth for targets, schemes, build settings, entitlements wiring, and resource references.

**Why over alternatives:**
- *Checked-in `.xcodeproj`*: notoriously merge-hostile, hides project-level changes in unreadable XML, easy to clobber.
- *Tuist*: more powerful but heavier; we don't need its module-graph features for a single workspace.
- *Pure Swift Package Manager (no Xcode project)*: insufficient — we have multi-platform app targets with entitlements, asset catalogs, Info.plist customization, and Mac vs. iOS deployment settings that SwiftPM still does not express well in 2026.

**Rules:**
- Every target (`CitybuilderiOS`, `CitybuilderMac`, `citybuilder-cli`) and every local Swift package reference is declared in `project.yml`.
- Bundle identifier `com.cedricziel.citybuilder` and the iCloud entitlement targeting `iCloud.com.cedricziel.citybuilder` are declared once and shared via XcodeGen YAML anchors.
- A `Makefile` (or equivalent script) provides `make generate` as the canonical way to (re)generate the project; `make` targets for `build`, `test`, `lint`, `format` shell out to `xcodebuild` after generation.
- CI MUST run `xcodegen generate` before any `xcodebuild` invocation.
- Contributors install XcodeGen via Homebrew (`brew install xcodegen`); the README documents this.

### D12. Pre-commit hooks from day one

A `.pre-commit-config.yaml` at the repo root SHALL be authored and installed before the first feature commit. Hooks MUST be managed by the [`pre-commit`](https://pre-commit.com) framework so that the tool inventory is declarative and identical across contributors and CI.

**Hooks to install at M0:**

| Stage | Hook | Purpose |
|---|---|---|
| `pre-commit` | `swiftformat` | Auto-format staged Swift files |
| `pre-commit` | `swiftlint` (strict) | Lint staged Swift files; fail on warnings |
| `pre-commit` | `check-yaml` | Validate `project.yml`, `.pre-commit-config.yaml`, OpenSpec YAML |
| `pre-commit` | `end-of-file-fixer` | Enforce trailing newline |
| `pre-commit` | `trailing-whitespace` | Strip trailing whitespace |
| `pre-commit` | `check-merge-conflict` | Block unresolved markers |
| `pre-commit` | `check-added-large-files` | Block files > 1 MB unless explicitly allowed (e.g. asset atlases via Git LFS or `--allow-large` annotation) |
| `pre-commit` | `forbid-xcodeproj` (local) | Custom hook: fail if a `.xcodeproj` or `.xcworkspace` is staged, since they are generated from `project.yml` |
| `commit-msg` | `conventional-pre-commit` | Enforce Conventional Commits (`feat:`, `fix:`, `chore:`, …) |

**Rules:**
- `make hooks` is the canonical installer: runs `pre-commit install` and `pre-commit install --hook-type commit-msg`.
- `make lint` and `make format` invoke SwiftLint and SwiftFormat directly (independent of git state) for ad-hoc use and IDE integration.
- The full hook suite MUST also run in CI as `pre-commit run --all-files`, gating merges. This catches drift if someone pushes without local hooks installed.
- Contributors install prerequisites once via `brew install pre-commit swiftlint swiftformat`. The README documents this.
- Hook versions in `.pre-commit-config.yaml` SHALL be pinned (no floating refs); upgrades are explicit, reviewed commits.

**Why this stack:**
- *`pre-commit` framework over Husky*: language-agnostic (we have no Node), better caching, declarative config, well-supported SwiftLint/SwiftFormat hooks.
- *SwiftFormat over swift-format (Apple)*: the de-facto Apple-community formatter; more rules, more configurable, broader IDE integration. Apple's `swift-format` is acceptable as an alternative but we standardize on one.
- *Conventional Commits enforced at commit-msg time*: aligns with the project mandate of semantic commits, prevents typo'd types reaching history.

### D13. Test-driven development is mandatory from day one

**Policy:** No production code SHALL land in `main` without an accompanying test that exercises the new or changed behavior. New behavior MUST be developed via the red-green-refactor cycle: write a failing test first, make it pass with the smallest possible change, then refactor with the test as a safety net. Code-then-test-after is not acceptable.

**Specs ARE the test inventory.** Every `#### Scenario:` block in `specs/**/*.md` MUST be backed by at least one automated test that fails when its WHEN/THEN expectation is broken. The scenarios in this change are the initial test backlog — implementation of any requirement begins by translating its scenarios into tests.

**Where tests live:**

| Layer | Framework | What to test |
|---|---|---|
| `CityCore` | `swift-testing` | Tick determinism, RNG seeding, command application, every spec scenario for terrain, buildings, roads, goods/production, warehouses/logistics, population, economy, simulation-core. Headless on any platform. |
| `CityPersistence` (file) | `swift-testing` | Codable round-trip, atomic write under simulated failure, version-migration framework, integrity checks. |
| `CityPersistence` (CloudKit) | `swift-testing`, gated | Sync triggers, LWW resolution, conflict prompts, offline fallback. Gated behind a `CITYBUILDER_CLOUDKIT_TESTS=1` env var; runs only with a developer iCloud account. CI runs the gate on demand, not by default. |
| `CityUI` | `swift-testing` + snapshot tests (deferred to post-MVP) | View-model logic must be testable headlessly; visual snapshot tests not required for MVP. |
| `CityRender2D` | targeted unit tests | Iso projection math, culling math, input intent translation. The SpriteKit scene tree itself is not unit-tested. |

**CI enforcement:**
- The PR check workflow MUST run all `swift-testing` suites and block merge on any failure.
- The PR check workflow SHALL run a code-coverage report and fail if `CityCore` coverage falls below a configured floor (initial target: 80% line, 70% branch). Other packages get coverage reporting but no gate in MVP.
- The PR check workflow SHALL run a `--diff-cover` style check: any added/changed lines in `CityCore` that lack test coverage block the merge. This is the mechanical enforcement of TDD.
- A spec-scenario coverage report (`scripts/check-scenario-coverage.swift`) maps every `#### Scenario:` in `specs/` to a test by naming convention (`Scenario: foo bar` → test name `testScenario_foo_bar` or similar). Missing mappings produce a warning at first, then become a hard gate once the M1 baseline is in.

**Pre-commit hook (light):**
- A local `pre-push` hook (`make hooks` installs it) runs `swift test` for `CityCore` and refuses pushes on failure. Other packages run in CI only to keep the pre-push fast.

**Headless runner:**
- The `citybuilder-cli` tool is a first-class test fixture: it can deterministically replay a save against N ticks of recorded commands, producing a final-state diff that test cases assert on. This supports high-leverage "play a scenario for 60 simulated seconds and assert outcome" tests.

**Why this stack:**
- *`swift-testing` over XCTest*: modern, expression-level diagnostics, parameterized tests, Swift 6 concurrency-aware. Apple's clear direction.
- *Spec scenarios as test inventory*: every requirement is already written as a testable WHEN/THEN. Free traceability matrix.
- *Diff-cover gate over absolute coverage threshold*: rewards adding tests with new code, doesn't punish legacy uncovered lines. Better TDD pressure.

**What this rules out:**
- "I'll add tests in a follow-up PR" — not allowed.
- Implementing a building, road, or production behavior without first translating its spec scenarios to failing tests.
- Refactors without a test that would have caught the regression. If the refactor surfaces a missing test, write it first.

## Risks / Trade-offs

- **Custom iso renderer is more work than `SKTileMapNode`** → Mitigation: keep the renderer dumb (snapshot-in, sprites-out); no game logic in SpriteKit. Cap MVP island size to keep node counts manageable.
- **CarrierPathfinding cost at scale** → Mitigation: cache road graph; invalidate only on road edits; A* with early termination; cap concurrent carriers per producer.
- **JSON save bloat at scale** → Mitigation: measure at MVP island size first; binary encoding is a known migration path with a version bump.
- **CloudKit account not signed in** → Mitigation: graceful fallback to local-only save; "Sign in to iCloud" banner; never block gameplay on sync.
- **iPhone screen real estate vs. Anno density** → Mitigation: iPhone gets larger default zoom, hides per-tile labels, surfaces info via tap-then-sheet. Game is identical underneath.
- **Apple Pencil hover detection only on newer iPads** → Mitigation: graceful fallback to tap-to-preview-place.
- **No prior Apple-game experience** → Mitigation: M0 is a SpriteKit hello-iso spike that derisks the renderer before any sim work. Architectural layering means a renderer rewrite later does not nuke the project.
- **Universal "three platforms" tax** → Mitigation: `CityUI` is shared; per-platform code is intentionally thin; CI runs all three.
- **SceneKit is in maintenance** → Mitigation: portraits are an opt-in, isolated module. If SceneKit becomes unviable, swap to RealityKit without touching the rest.

## Migration Plan

Not applicable — greenfield project. The "migration" is the initial workspace and package skeleton. Rollback is "delete the directory."

For save-format and CloudKit-schema migrations once shipped: the `version` field and a `Migrator` system in `CityPersistence` will translate older saves forward on load. Schema-breaking CloudKit changes are forbidden in v1.x; major bumps require a new CKRecord type.

## Open Questions

- **Asset pipeline**: hand-authored sprite atlases vs. Tiled vs. Aseprite export? Decide before M3.
- **Music & SFX**: deferred to post-MVP. Architecture should expose a `WorldEvent` stream that an audio layer can subscribe to later.
- **Time controls**: pause / 1x / 2x / 3x speed multipliers? Almost certainly yes, but UI placement is a polish question.
- **Game-over conditions**: bankruptcy ends the game? Or warning + grace period? Decide while building economy spec.
- **iPhone "companion mode"**: is it the same app idiom-adapted, or a separate stripped-down UX flow? Default assumption: same app, adaptive layout.
- **Pencil & trackpad gestures**: which gestures are needed beyond pan/zoom/tap? Investigate during M2.
- **Localization scope for MVP**: English-only acceptable for first ship?
