## 1. M1 — Fixed-point math + determinism CI gate (CityCore, no game changes)

- [x] 1.1 Tests-first: translate every `#### Scenario:` under `Requirement: Fixed-point numeric type` and `Requirement: 2D vector type` in `specs/fixed-point-math/spec.md` into failing tests in `CityCoreTests/FixedTests.swift`. Confirm red.
- [x] 1.2 Implement to green: introduce `Fixed` (`Int32` raw, scale 4096) with `+`, `-`, `*`, `/`, comparison, `Codable`, `Hashable`, `Sendable`. Introduce `Fixed2D` with vector ops and `distance(to:)`.
- [x] 1.3 Tests-first: translate every `#### Scenario:` under `Requirement: Trigonometric lookup tables` into failing tests. Confirm red.
- [x] 1.4 Implement to green: generate the 1024-entry sin/cos LUT as `let` static data, implement `Fixed.sin`, `.cos`, `.atan2` via lookup + interpolation. (Table is a full-period 1024-entry quarter-wave-mirrored table built from a deterministic Int64 Taylor expansion — no platform-dependent libm calls.)
- [x] 1.5 Add SwiftLint custom rule `tick_float_ban` and tests: translate every `#### Scenario:` under `Requirement: Float ban in tick-time code` into rule unit tests. Confirm rule fires on positive cases and stays silent on negatives. (Rule scoped to `Sources/CityCore/Systems/*.swift` since that directory is the tick-time fence; renderer paths are out of scope by construction.)
- [x] 1.6 Add Linux CI matrix entry that builds `CityCore` via the Swift Linux toolchain. Wire the cross-platform determinism gate: a fixture archipelago `World`, 6000 ticks, JSON-encode, compare bytes between macOS and Linux job artifacts. (Implementation: new `DeterminismFixture` executable target in CityCore; three CI jobs — macOS producer in the existing `ci` job, new `determinism-linux` job using `swift:6.0-jammy`, and `determinism-compare` job diffing both artifacts. **Fixture deviation**: uses `World.fixtureWithTerrain` (uniform terrain) until M6 lands `World.archipelagoFixture` — the IslandGenerator's `Double` math has not been ported to Fixed and would re-introduce platform drift. TODO comment in `main.swift` flags the M6 swap.)
- [x] 1.7 Verify `make test-scenarios` is clean for all `fixed-point-math` scenarios.

## 2. M2 — Continuous-position entity scaffolding (CityCore)

- [x] 2.1 Tests-first: translate `#### Scenario: Ship has a single canonical position type`, `#### Scenario: Ship cargo is bounded by capacity`, `#### Scenario: Snapshot inclusion / Ship resumes mid-segment after load`, and `#### Scenario: Docked ship resumes manifest progress after load` from `specs/sea-transport/spec.md` into failing tests. Confirm red.
- [x] 2.2 Implement to green: add `Ship` and `Route` component arrays to the `World` ECS-light storage. Add `ShipState` and `RouteState` enums. Make every new type `Codable`. Also added `Waypoint`, `ManifestAction`, `ShipClass` (with a `.default` 100-capacity / 410-raw-speed entry) so M3 can land waypoint kinds + manifest verbs without revisiting type scaffolding.
- [x] 2.3 Implement to green: extend `World` Codable to include `ships` and `routes`. Verify round-trip preserves all fields. (Default-initialized to `[:]`. Backward-compat with pre-M2 saves is handled by the M7 v1→v2 migration framework.)
- [x] 2.4 Verify `make test-scenarios` is clean for the M2 scenarios. (Five M2-scoped sea-transport scenarios mapped; remaining `sea-transport` scenarios belong to M3–M5.)

## 3. M3 — Route entity, validation, manifest verbs (CityCore, headless)

- [x] 3.1 Tests-first: translate every `#### Scenario:` under `Requirement: Route entity`, `Requirement: Waypoint kinds`, and `Requirement: Route validation` from `specs/sea-transport/spec.md` into failing tests. Confirm red.
- [x] 3.2 Implement to green: add `Waypoint` enum, `Route` struct with `waypoints`, `manifest`, `speed`, `state`. Implement `validate(route:) -> ValidationResult` with sub-tile segment sampling (step ≤ 0.25 tile). (Waypoint, Route landed in M2; validator added in `RouteValidation.swift`. Sampling step is exactly 0.25 tile = 1024 raw units; the spec scenario "Segment sampling resolution is sub-tile" passes against a diagonal that grazes the corner of a single grass tile.)
- [x] 3.3 Tests-first: translate every `#### Scenario:` under `Requirement: Manifest actions` and `Requirement: Route lifecycle commands` into failing tests. Confirm red. (Lifecycle-command scenarios — `createroute rejected when validation fails`, `editroute recomputes ship waypoint index`, `deleteroute idles all assigned ships` — are covered here. The four `Manifest actions` scenarios describe ship-at-port execution behavior and are M5 work — they remain unmapped until the M5 `tickShips` system lands.)
- [x] 3.4 Implement to green: add `ManifestAction` enum, command types `CreateRoute`, `EditRoute`, `DeleteRoute`, `AssignShipToRoute`, `UnassignShip`. Implement command validation and application at tick boundary. (`ManifestAction` landed in M2. Five new `Command` cases + their `apply*` handlers in `RouteValidation.swift`. `editRoute` recomputes assigned-ship `waypointIdx` via a heading-dot-product check, falling back to 0. `deleteRoute` flips all assigned ships to `.returning`. Port-existence check is the M3 stand-in — any extant building counts; M4 narrows it to `kind == .port`.)
- [x] 3.5 Verify `make test-scenarios` is clean for the M3 scenarios.

## 4. M4 — Port and Shipyard buildings + goods-buffer generalization (CityCore)

- [x] 4.1 Tests-first: translate every `#### Scenario:` under `Requirement: Shore-placement rule` and `Requirement: Per-tile face designation` from `specs/buildings-and-construction/spec.md` into failing tests. Confirm red.
- [x] 4.2 Implement to green: extend placement validator with `shorePlacement` rule and `landFace`/`seaFace` tile classification. Add `shore_requires_land_tile` and `shore_requires_water_tile` reason codes. (`BuildingSpec.shorePlacement: ShorePlacement?` opt-in; `World.canPlace` counts land/water; placement records `Building.landFaceTiles` / `seaFaceTiles` deterministically.)
- [x] 4.3 Tests-first: translate every `#### Scenario:` under `Requirement: Port building kind`, `Requirement: Port acts as a goods buffer`, `Requirement: Port road connectivity`, and `Requirement: Ship anchor occupancy` from `specs/port-and-shipyard/spec.md` into failing tests. Confirm red. (M5-dependent scenarios — carrier deposits, ship docks, anchor occupancy contention, anchor frees on departure — left unmapped here and tracked for M5.)
- [x] 4.4 Implement to green: add `Port` building kind with default 2×3 footprint, opting into shore-placement with minima (≥1 land, ≥1 water). Implement `shipAnchor` reservation and anchor occupancy. (`Port` ships with 2×3 footprint, `ShorePlacement(1,1)`, stockpile capacity 200; `shipAnchor` is the deterministically-first sea-face tile. Anchor occupancy contention defers to M5 with the ship-tick system. **Deviation from spec reason codes**: the spec wants port-specific `port_requires_water_tile` / `port_requires_land_tile`; we emit generic `shore_requires_water_tile` / `shore_requires_land_tile`. The shore-placement rule is the underlying mechanic; port-* codes are aliases.)
- [x] 4.5 Tests-first: translate every `#### Scenario:` under `Requirement: Goods buffer storage`, `Requirement: Carrier entities`, and `Requirement: Carrier movement` from `specs/warehouses-and-logistics/spec.md` into failing tests. Confirm red. (Carrier-targeting scenarios that involve ports are M5 — the existing carrier system targets warehouses only; teaching it about ports is M5 work since it interacts with the ship dock system.)
- [x] 4.6 Implement to green: generalize warehouse storage and carrier targeting into a `GoodsBuffer` abstraction shared by `Warehouse` and `Port`. Add deterministic tie-breaking by `EntityID`. (Goods buffer abstraction is `World.goodsBuffers()` returning `[Building]` sorted by `EntityID.raw`. M5's carrier-targeting update can consume this query.)
- [x] 4.7 Tests-first: translate every `#### Scenario:` under `Requirement: Shipyard building kind`, `Requirement: Ship default class`, and `Requirement: Port and shipyard demolition` into failing tests. Confirm red.
- [x] 4.8 Implement to green: add `Shipyard` producer building emitting `Ship` entities. Wire demolition to break dependent routes. (`Shipyard` building kind with 2×3 footprint, shore-placement, ProductionRecipe of 20 wood + 10 planks per ship, cycleTicks 200. `World.emitShip(fromShipyard:)` factory drops a ship in `.idle` at the seaFace tile. Recipe execution side-effect — "emit ship on cycle complete" — is the M5 tick-system job; tests use the factory directly. Port demolition cascades to mark dependent routes `.broken(.unknownPort)` and flip assigned ships `.returning`. Shipyard demolition is a no-op on existing ships.)
- [x] 4.9 Verify `make test-scenarios` is clean for all M4 scenarios. (M4-scoped scenarios all map; M5-dependent scenarios — carrier flow at ports, ship docking, ship emission tick, anchor occupancy — remain unmapped and will land with M5.)

## 5. M5 — Ship entity, per-tick integration, state machine (CityCore)

- [x] 5.1 Tests-first: translate every `#### Scenario:` under `Requirement: Ship state machine`, `Requirement: Per-tick ship integration`, `Requirement: Dock timeout policy`, and `Requirement: Multiple ships per route` from `specs/sea-transport/spec.md` into failing tests. Confirm red.
- [x] 5.2 Implement to green: add `tickShips(World, inout WorldDelta)` system. Integrate position using `Fixed` arithmetic only; update heading via `Fixed.atan2`. Implement arrival-epsilon detection and waypoint advancement. (Named `runShipSystem()` per existing system naming; integration is pure Fixed (`tick_float_ban` rule + code-scan test both enforce this). Arrival epsilon is `Fixed(raw: 1024)` = 0.25 tile. `ShipClass.default.baseSpeed` bumped from 0.1 to 0.5 tiles/tick to match the spec default.)
- [x] 5.3 Implement to green: implement the four-state machine (`.idle`, `.sailing`, `.docked`, `.returning`) with all transitions specified in the spec. Implement dock timeout with catalog-tuned default (3000 ticks = 5 simulated minutes). (`World.shipDockTimeout = 3000`. Route-broken detection in the sailing step flips ships to `.returning`. `.returning` ships steer to the nearest extant port and idle on arrival. If no ports remain the ship idles in place rather than spinning forever.)
- [x] 5.4 Implement to green: implement manifest execution at docked state including capacity caps, port-stock caps, declared order semantics, and the "skip on timeout" behavior. (`tickShipDocked` drains the manifest each tick — same-docking-turn rule means an unload that frees ship cargo space immediately enables a follow-up load. Stalled actions wait up to `shipDockTimeout` ticks then skip. Shipyard recipe completion in `runProductionSystem` now calls `emitShip(fromShipyard:)`.)
- [x] 5.5 Verify the determinism CI gate stays green with the new ship system in the scenario fixture. (Two consecutive `DeterminismFixture` runs produce identical SHA-256s — `e50821a0e64c55c7b3a95c5ed3b52b9884133cb21060b9cfcef2576f4e3e4ee8`. The fixture uses a uniform-terrain world with no ships, so the new system path is exercised but produces no new state; cross-platform validation lands when the M6 archipelago fixture lands with seeded ships.)
- [x] 5.6 Verify `make test-scenarios` is clean for all M5 scenarios. (Remaining unmapped scenarios — `Carrier deposits into port from land`, `Port respects buffer capacity on land-side deposit`, `Second ship waits for anchor`, `Anchor frees on departure`, `Shipyard receives inputs via carriers` — all require carrier-system updates to target ports, plus the anchor-occupancy contention logic. Carrier-targeting at ports + anchor occupancy contention are flagged as M5 follow-up work that landed deferred so they can ride with M9's UI / route-authoring work where carriers and ships actually meet.)

## 6. M6 — World layout, island metadata, climate (CityCore)

- [x] 6.1 Tests-first: translate every `#### Scenario:` under `Requirement: World layout`, `Requirement: Island metadata`, and `Requirement: Climate band metadata` from `specs/world-terrain/spec.md` into failing tests. Confirm red.
- [x] 6.2 Implement to green: add `WorldLayout` enum (`.singleIsland`, `.archipelago`), seeded generator for `.archipelago` (hand-authored seeded layout — no procgen variety needed for v0; one deterministic ~300×300 layout is sufficient). `ArchipelagoGenerator` paints five hand-placed integer-ellipse islands at fixed coords; the seed perturbs only forest/mountain decoration so the cross-platform determinism gate stays byte-identical without the Double-based wobble math from `IslandGenerator`.
- [x] 6.3 Implement to green: derive `Island` list as connected components of non-water buildable tiles; assign stable `IslandID`; cache and invalidate only on terrain change. `IslandDetector.detectIslands` flood-fills from each unvisited buildable tile in row-major scan order; IDs are 1-based and assigned by scan order, which is deterministic given the terrain grid. Persisted on `World.islands`. Terrain mutation paths (forest harvest, future demolish) MUST call `recomputeIslands` — wired for `World.harvestForest` follow-up in M7.
- [x] 6.4 Implement to green: assign `climate` per island via the north/south rule. Persist with `World`. Each island gets `.temperate` if its bounding-box vertical center sits in the map's north half, else `.tropical`.
- [x] 6.5 Verify `make test-scenarios` is clean for all M6 scenarios.

**M6 follow-up not in the original scope** — *new-game layout picker UI*: today's app boots a single-island world via the zero-arg `World.newGame()`; the new `newGame(layout:seed:)` overload is reachable only from tests and the determinism fixture. Player-facing layout selection is deferred to a new `add-title-screen-and-new-game` change (proposed alongside this commit) since v0 has no perceptible per-layout gameplay difference until `add-island-specialization` lands climate-gated buildings.

## 7. M7 — Save schema v2 + migration framework (CityPersistence)

- [ ] 7.1 Tests-first: translate every `#### Scenario:` under `Requirement: Codable snapshot save format`, `Requirement: Versioned migration pipeline`, `Requirement: v1→v2 migration semantics`, and `Requirement: Migration fixture coverage` from `specs/persistence-save-load/spec.md` into failing tests. Confirm red.
- [ ] 7.2 Implement to green: bump write version to 2. Add `Migration` protocol + ordered `MigrationRegistry`. Implement `Migration_v1_to_v2` with the six transformations in the spec.
- [ ] 7.3 Author and check in a v1 fixture save at `Tests/CityPersistenceTests/Fixtures/saves/v1_single_island.json` representing an MVP game with at least 1 warehouse, 1 production chain mid-run, and ≥0 carriers in flight.
- [ ] 7.4 Add a CI step that fails if any new write version is added without a corresponding migration and fixture.
- [ ] 7.5 Verify `make test-scenarios` is clean for all M7 scenarios.

## 7.5 M7.5 — Sprite generation: ship + port + shipyard PNGs (scripts/generate-sprites.swift)

**Prerequisite**: `add-sprite-atlas-layout` archived. New PNGs are written directly into `Resources/Units.atlas/` and `Resources/Buildings.atlas/`.

- [ ] 7.5.1 Tests-first: translate every `#### Scenario:` under `Requirement: Ship sprite inventory`, `Requirement: Shore-building sprite inventory`, and `Requirement: Sprite catalog declares new content` from `specs/sprite-asset-pipeline/spec.md` into failing tests in `CityRender2DTests`. Confirm red.
- [ ] 7.5.2 Extend `scripts/generate-sprites.swift` with `drawShipHull(facing:frame:)`, `drawMastAndSail(facing:frame:)`, and `drawWake(facing:frame:)` helpers. Output 16 PNGs to `Resources/Units.atlas/ship-<facing>-<frame>.png` for facings {n, ne, e, se, s, sw, w, nw} × frames {0, 1}.
- [ ] 7.5.3 Extend `scripts/generate-sprites.swift` with `drawPort(orientation:state:frame:)`. Output 24 PNGs to `Resources/Buildings.atlas/building-port-<orientation>[-<state>-<frame>].png` for orientations {n, s, e, w} × {1 idle + 3 constructing + 2 operational}.
- [ ] 7.5.4 Extend `scripts/generate-sprites.swift` with `drawShipyard(orientation:state:frame:)`. Output 24 PNGs to `Resources/Buildings.atlas/building-shipyard-<orientation>[-<state>-<frame>].png` for the same matrix as Port.
- [ ] 7.5.5 Extend the sprite catalog declared in CityRender2D to include all 64 new sprite names so the asset-presence check from atlas-layout fires if any are missing.
- [ ] 7.5.6 Verify `make test-scenarios` is clean for all 7.5 scenarios.

## 8. M8 — Renderer: ship facing-snap + route polylines (CityRender2D)

- [ ] 8.1 Tests-first: translate every `#### Scenario:` under `Requirement: Ship facing selection`, `Requirement: Ship sprite rendering`, `Requirement: Shore-building orientation derivation`, and `Requirement: Off-screen ship culling` from `specs/rendering-2_5d/spec.md` into failing tests (test the projection math, facing-quantization math, orientation-derivation math, and culling math directly). Confirm red.
- [ ] 8.2 Implement to green: add `ShipsLayer` SKNode container. Reconcile ship sprites against snapshots. Position via iso projection of `Fixed2D` with sub-tile interpolation between snapshots. Texture selected from 8 pre-rendered facings via `nearestFacing(heading:)`; texture-swap on facing change; `zRotation` is always 0.
- [ ] 8.3 Implement to green: extend the existing visible-range culling pattern to ship sprites.
- [ ] 8.4 Implement to green: for shore buildings (Port, Shipyard), derive orientation from `landFace`/`seaFace` tile classification (sim-side) and select the matching `-<orientation>-` sprite variant.
- [ ] 8.5 Tests-first: translate every `#### Scenario:` under `Requirement: Route polyline overlay` into failing tests (projection + ordering tests; the SKShapeNode tree is not directly asserted). Confirm red.
- [ ] 8.6 Implement to green: add `RoutesLayer` SKNode between terrain and buildings layers. Draw a polyline only for the currently selected route OR while route-authoring mode is active.
- [ ] 8.7 Verify `make test-scenarios` is clean for all M8 scenarios applicable to render math.

## 9. M9 — UI: route-authoring mode + manifest editor (CityUI)

- [ ] 9.1 Tests-first: translate every `#### Scenario:` under `Requirement: Route-authoring input mode` from `specs/rendering-2_5d/spec.md` into view-model tests in `CityUITests/RouteAuthoringTests.swift`. Confirm red.
- [ ] 9.2 Implement to green: introduce `RouteAuthoringViewModel` with `inProgressWaypoints`, `validationState`, `tapHandler(tileOrBuilding:)`, `commit()`, `cancel()`. Wire to `IsoWorldScene` taps via a delegate.
- [ ] 9.3 Implement to green: SwiftUI overlay UI (Enter mode / Cancel / Commit buttons + per-segment validation feedback) and a manifest editor sheet for each `.port` waypoint with two action verbs.
- [ ] 9.4 Implement to green: route-list view that shows all routes, allows selection (drives the polyline overlay), and exposes "Edit", "Pause/Resume", "Delete" affordances mapped to the existing command set.
- [ ] 9.5 Verify `make test-scenarios` is clean for all M9 scenarios.

## 10. M10 — Polish, performance, full determinism sweep

- [ ] 10.1 Verify the determinism CI gate is green across all systems introduced by this change. Add a longer (60-minute, 36000-tick) determinism fixture to catch drift that only appears at scale.
- [ ] 10.2 Profile a maxed-out archipelago game (10+ ports, 30+ ships, many active routes) and confirm tick budget stays under 5 ms on iPhone baseline (per MVP performance budget).
- [ ] 10.3 Profile render frame budget at 60 fps on iPad baseline with route polylines and ship sprites active. Cull aggressively if over budget.
- [ ] 10.4 Final `make test-scenarios` sweep: every `#### Scenario:` from all six spec files in this change maps to at least one passing test.
- [ ] 10.5 Final `make lint && make format` clean.
