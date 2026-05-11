## Why

We are starting a greenfield Apple-exclusive city-builder ("Anno-like") from zero code. Before writing application code we need a foundation that locks in the high-level platform shape, the rendering/simulation split, the persistence/sync model, and the MVP feature set — so that every subsequent change can fit into a coherent, shippable architecture rather than re-deciding fundamentals each milestone.

The MVP target is: one island, tile-based construction, roads + warehouses, the Wood → Planks → Houses production chain, population needs, a basic money balance, save/load, and iCloud sync — delivered as a universal Apple app (iPhone, iPad, Mac) with a 2.5D isometric world and optional 3D building portrait moments.

## What Changes

- Introduce a Swift workspace with a framework-free `CityCore` Swift package that owns the deterministic simulation (tiles, buildings, roads, carriers, goods, population, money, tick loop, Codable snapshots). No UIKit, SwiftUI, SpriteKit, or SceneKit imports allowed in this package.
- Introduce a `CityPersistence` Swift package that snapshots `CityCore` state to disk (JSON v0 for debuggability) and syncs it via CloudKit private database as a versioned `CKAsset` blob.
- Introduce three thin SwiftUI app shells — iOS, iPadOS, macOS — sharing a `CityUI` package for HUD, build palette, inspectors, menus.
- Add a SpriteKit-based 2.5D isometric renderer embedded via `SpriteView`, with custom tile culling, camera, and input gestures (touch + pointer + Apple Pencil).
- Add an opt-in SceneKit "building portrait" view (Flavor A 3D moments) for inspecting individual buildings as rotatable USDZ models.
- Establish the MVP gameplay loop: one fixed island, tile placement, road graph, warehouse storage, three-stage production chain (Wood → Planks → Houses), one population tier with food + housing needs, single-currency money balance with tax income and build costs.
- Establish save/load: atomic local file write + load on launch; CloudKit sync on background + manual trigger; one active session per game with last-write-wins for v0.
- Establish a deterministic 10 Hz tick model with frame-interpolated rendering, runnable headless in unit tests on any platform.
- Establish a strict TDD policy: no production code lands without a failing test written first. Every `#### Scenario:` in the spec set is treated as part of the test backlog. CI enforces test pass, a `CityCore` coverage floor, diff-cover on changed lines, and a spec-scenario-to-test mapping check.
- Carriers physically walk roads between warehouses and consumers (deep-simulation flavor) rather than abstract throughput rates.
- iPhone surface ships as full-game capable but defaults to a "compact" play mode optimized for short sessions; full creative play is iPad/Mac primary.

## Capabilities

### New Capabilities

- `world-terrain`: One fixed island map, tile grid coordinates, terrain types (grass / forest / beach / water / mountain), build-eligibility rules per terrain.
- `buildings-and-construction`: Building catalog, footprints, placement validation, construction state, demolition, ownership of tiles, build cost.
- `road-network`: Road tile placement, road graph derivation, connectivity queries, pathfinding (A*) over the road graph for carriers.
- `goods-and-production`: Goods catalog (wood, planks, …), producer/consumer building behaviors, production timing, input/output stockpiles, the Wood → Planks → Houses chain.
- `warehouses-and-logistics`: Warehouse storage capacity, carrier units that physically traverse the road network to move goods between producers, warehouses, and consumers.
- `population-and-needs`: Population housed in residential buildings, per-pop needs (food, housing), satisfaction tracking, growth/decline rules, tax generation.
- `economy`: Single-currency money balance, build/upkeep costs, tax income, bankruptcy and game-over rules, money UI surface.
- `simulation-core`: Deterministic fixed-tick simulation, ECS-light data layout, system ordering, snapshotting, headless testability.
- `persistence-save-load`: Atomic Codable save to local app support directory, autosave cadence, manual save/load UI, save versioning and forward-compat policy.
- `icloud-sync`: CloudKit private-database sync of save blobs as `CKAsset`, conflict policy (LWW v0), sync triggers (background, manual), offline behavior, account-not-signed-in fallback.
- `rendering-2_5d`: SpriteKit isometric tile renderer, camera pan/zoom, sprite culling, building/carrier sprites driven by snapshots, gesture input.
- `building-portraits-3d`: SceneKit-based rotatable 3D portrait of a selected building (Flavor A); lazy-loaded USDZ assets, dismissable overlay.
- `platform-shells`: Universal-target SwiftUI app shells for iPhone, iPad, Mac with adaptive HUD/palette/inspector layouts, hotkey support on Mac, Apple Pencil precision on iPad, Continuity/Handoff between devices.

### Modified Capabilities

(none — greenfield project)

## Impact

- **New repository structure**: Xcode project generated by [XcodeGen](https://github.com/yonaskolb/XcodeGen) from a checked-in `project.yml`; multiple local Swift Packages (`CityCore`, `CityPersistence`, `CityUI`, `CityRender2D`, `CityRender3D`) under `Packages/`; thin app targets `CitybuilderiOS` (universal iPhone + iPad idiom) and `CitybuilderMac`, plus a `citybuilder-cli` executable for headless simulation. The generated `.xcodeproj` is gitignored.
- **Dependencies**: Apple frameworks only at runtime (SwiftUI, SpriteKit, SceneKit, CloudKit, GameController for Mac). Build-time tooling installed via Homebrew: `xcodegen`, `pre-commit`, `swiftlint`, `swiftformat`. No third-party runtime libraries in MVP.
- **Developer experience from day one**: `.pre-commit-config.yaml` enforces SwiftFormat, strict SwiftLint, YAML validation, whitespace hygiene, a guard against committing generated `.xcodeproj`, and Conventional Commits on commit-msg. CI runs `pre-commit run --all-files` as a merge gate.
- **Capabilities required from Apple ecosystem**: iCloud entitlement, CloudKit container, Universal Purchase, Game Center entitlement reserved for post-MVP.
- **Testing surface**: `CityCore` must be 100% headless-testable on any platform (CI on Linux possible). UI tests are platform-specific. TDD is mandatory: red-green-refactor for all new behavior; every `#### Scenario:` block in `specs/` maps to at least one `swift-testing` test; CI gates merges on test pass, coverage floors (≥80% line / ≥70% branch in `CityCore`), and diff-cover for changed lines.
- **Asset pipeline**: Need a pipeline for tile/building sprite atlases and for USDZ building portraits; tooling to be chosen in design.
- **Performance budget**: 10 Hz simulation tick must complete in &lt; 5 ms on iPhone for a maxed-out MVP island. Renderer must hold 60 fps on iPad baseline.
- **Lock-in**: Apple-only stack. Acceptable per project mandate; future Linux/Windows port would require reimplementing renderer + persistence shells but `CityCore` would survive.
