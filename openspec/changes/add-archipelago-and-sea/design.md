## Context

The MVP delivers a single fixed island with a tile-locked simulation: integer tile coordinates, road-graph A* for carriers, deterministic 10 Hz tick, Codable snapshots. Every moving thing in `CityCore` today is tile-locked.

This change introduces three things that the MVP architecture did not anticipate:

1. **A second, continuous motion model** for sea entities (ships) living alongside the existing integer-tile model for land entities (carriers).
2. **A first-class persistent route entity** — a player-authored polyline of waypoints with a cargo manifest — that outlives the ships that run it.
3. **A building (Port) that straddles two coordinate systems** — land tiles on one face for road-connected carriers, a sea anchor on the other face for ships.

The user explicitly chose **Shape C** (archipelago + economic specialization) and **autopilot steering** during the explore session. Specialization itself is deferred to a follow-up change; this change delivers only the architectural lift. The autopilot choice is load-bearing: it eliminates runtime obstacle avoidance and turns route validity into an authoring-time concern, which collapses what could have been a steering-behavior subsystem into a ~50-line per-tick loop.

Hard constraints carried forward from MVP:
- Apple-frameworks-only at runtime; no third-party deps.
- `CityCore` is framework-free Swift; must build on Linux toolchain.
- 10 Hz deterministic tick. Given identical state + inputs + RNG seed, two simulations produce byte-identical results.
- Save format must survive across versions.

## Goals / Non-Goals

**Goals**
- A multi-island world that ships can sail between, with goods carried by player-authored routes.
- Continuous-position ship movement that *feels* like ships (heading, turn radius cue, smooth motion) while staying deterministic.
- A route authoring experience that is the primary spatial-skill expression of the gameplay (drawing efficient routes, choosing safe paths around landmasses, scheduling cargo).
- A clean boundary between land and sea: ports are the *only* place goods cross between the two coordinate systems.
- A migration story for v1 saves: existing single-island worlds load cleanly into the new model.

**Non-Goals**
- Climate-driven specialization, neutral merchant, AI trading factions — these move to `add-island-specialization` and beyond.
- Procedural archipelago generation. v0 ships hand-authored seeded layouts; procgen is a follow-up.
- Manual per-voyage piloting. Steering is autopilot only. The player edits the route; the ship runs it.
- Pirates, naval combat, storms, ship damage.
- Multiple cargo verbs beyond `loadUpTo` / `unloadUpTo`.
- Procedurally generated ship variants. One ship class at v0.

## Decisions

### D1. Bundle scope — topology + ports + ships, ship specialization later

This change delivers multi-island, ports, shipyards, ships, and routes — and nothing else. Specialization (climate-gated goods, per-island production rules, neutral merchant) lives in `add-island-specialization`, a smaller follow-up.

**Why over alternatives:**
- *Bundle specialization in*: makes this change too large to evaluate; couples a content question to an architectural one.
- *Ship specialization without topology*: degenerate — no place for ships to sail.
- *Topology without ships*: also degenerate — unreachable islands.

The three pieces in this change are mutually load-bearing; specialization is additive on top.

### D2. World topology — one unified grid

The archipelago is modeled as a **single rectangular tile grid** with water tiles separating landmasses. An "island" is metadata (a connected component of non-water buildable tiles) cached at world-gen time, not a separate coordinate system.

```
   single-island layout              archipelago layout
   ┌────────────────────┐            ┌─────────────────────┐
   │░░░░░░░░░░░░░░░░░░░░│            │░░░██░░░░░░░░░██░░░░░│
   │░░██████████████░░░░│            │░░██░░░░░░██░░░░░██░░│
   │░░██████████████░░░░│            │░░░░░░██████████░░░░░│
   │░░██████████████░░░░│            │░░██████░░░░░██░░░░░░│
   │░░░░░░░░░░░░░░░░░░░░│            │░░██░░░░░░██████░░░░░│
   └────────────────────┘            └─────────────────────┘
   80×80, MVP                         ~300×300
```

**Why over alternatives:**
- *Per-island grids with separate sea space*: cleaner conceptually, but doubles the number of coordinate systems, complicates rendering culling, and forces every sea↔land interaction to translate between two spaces.
- *Multiple worlds per save*: unnecessary; one large grid is plenty.

Memory cost at 300×300 with 16-byte tile records is ~1.4 MB — negligible.

### D3. Two coexisting motion models, ports as the only bridge

`CityCore` ships with two distinct entity motion models from this change onward:

```
   Land motion model (unchanged from MVP)
   ─────────────────────────────────────────
   Carrier { tile: (Int x, Int y),
             pathIndex: Int,
             path: [Tile] }
   Tick: advance one tile every (1/speed) ticks.

   Sea motion model (new)
   ─────────────────────────────────────────
   Ship { pos: Fixed2D,
          heading: Fixed,
          waypointIdx: Int,
          state: ShipState }
   Tick: integrate pos toward route.waypoints[waypointIdx]
         by speed * dt. Advance waypointIdx on arrival.
```

The two never need to share a coordinate system because **ports are the only place goods cross between them.** A port has a tile footprint (used by carriers) AND a sea anchor coordinate (used by ships). A carrier deposits into the port's `stored[Good]` dictionary; a ship reads/writes the same dictionary from its side.

**Why over alternatives:**
- *Unify both into continuous positions*: would force carriers onto fixed-point math too, blow up the save size, and break the existing road-graph A*.
- *Unify both into tiles*: defeats the entire purpose; ships on tile rails do not feel like ships.

### D4. Steering = autopilot. Routes are polylines authored by the player.

The player draws a route as a sequence of waypoints. The ship follows the polyline waypoint-by-waypoint at constant speed. No per-tick obstacle avoidance, no boids, no A*-at-runtime.

```
   Per-tick ship update (sketch):

   for ship in world.ships where ship.state == .sailing:
       route = world.routes[ship.routeID]
       target = route.waypoints[ship.waypointIdx].position
       dir = normalize(target - ship.pos)
       ship.pos += dir * route.speed * dt
       ship.heading = atan2(dir.y, dir.x)
       if distance(ship.pos, target) < arrivalEpsilon:
           ship.waypointIdx = (ship.waypointIdx + 1) % route.waypoints.count
           if waypoint is .port:
               ship.state = .docked
               enqueue(ship, manifestActionsFor: waypoint.portID)
```

**Why over alternatives:**
- *Direct manual piloting*: incompatible with the city-builder loop; would require player to babysit every ship.
- *Hybrid (player draws, ship avoids locally)*: tempting, but the runtime cost (continuous obstacle test against tile edges) is significant and the gameplay payoff is small once routes are authored correctly. We can add it as polish later if needed.
- *Auto-routed (player picks endpoints, system computes path)*: removes the spatial-skill expression the user explicitly wanted.

Arrival epsilon, turn rate, and speed are tuning parameters in the catalog (per ship class once we have more than one).

### D5. Route is a first-class persistent entity, decoupled from ships

```
   Route {
     id: RouteID
     waypoints: [Waypoint]   // ordered, last waypoint loops to first
     manifest: [PortID: [ManifestAction]]
     speed: Fixed            // assigned per route, not per ship (for now)
     state: .active | .broken
   }

   Waypoint = .sea(Fixed2D) | .port(PortID)

   ManifestAction = .loadUpTo(Good, Int) | .unloadUpTo(Good, Int)

   Ship {
     id: ShipID
     routeID: RouteID?
     pos: Fixed2D
     heading: Fixed
     waypointIdx: Int
     cargo: [Good: Int]
     state: .idle | .sailing | .docked | .returning
   }
```

A route can have zero or more ships assigned. Killing a ship leaves the route alive; the player can build a new ship and re-assign. Editing the route while a ship is en route recomputes the ship's effective next-waypoint from the new list (see D11).

**Why this is load-bearing:** it solves a long list of edge cases by data-modeling (ship destroyed, ship replaced, multiple ships per route for throughput, route paused, route edited) rather than special-casing.

### D6. Cargo manifest — two verbs at v0

Manifest actions: **`.loadUpTo(good, qty)`** and **`.unloadUpTo(good, qty)`**. No "wait until full," no conditional loads, no priority.

```
   Example A→B→A route:
   ┌─────────────────────────────────────┐
   │ Port A                              │
   │   • loadUpTo(wood, 50)              │
   │   • unloadUpTo(food, 30)            │
   │ Sea waypoint (open water)           │
   │ Port B                              │
   │   • unloadUpTo(wood, 50)            │
   │   • loadUpTo(food, 30)             │
   │ → loops back to Port A              │
   └─────────────────────────────────────┘
```

**Why over alternatives:**
- *Anno-1404-style rich manifests* (wait-until-full, priorities, conditional): more game but much more UI surface. Defer to a polish change.
- *Symmetric "swap" verb*: less flexible than two independent verbs and obscures the data model.

Deadlock policy: a docked ship that cannot fulfil any action of its current port manifest (port empty for an unload-up-to-N, or port full for a load-up-to-N) waits at most **dockTimeout** ticks (catalog-tuned, ~5 minutes of real time) and then proceeds to the next waypoint regardless. This is the "skip on timeout" call from the explore session — it prevents an entire route from deadlocking on one bottleneck.

### D7. Fixed-point math (`Fixed` type) for sea positions

Continuous positions in `CityCore` use a `Fixed` numeric type with implicit scale **1/4096 tile** (`Int32` storage, 12 fractional bits, ~±524k tile dynamic range — far more than needed for a 300-tile world).

```
   struct Fixed: Hashable, Codable {
       let raw: Int32
       static let scale: Int32 = 4096       // 2^12
       // arithmetic: +, -, * (with shift correction), /
   }
   struct Fixed2D: Hashable, Codable {
       let x: Fixed
       let y: Fixed
   }
```

Trigonometry (`atan2`, `sin`, `cos`) goes through a 1024-entry lookup table over Fixed angles. The lookup table is `let` static data, identical on every platform.

**Float ban in tick code:** `Float` and `Double` are forbidden in any function reachable from `World.tick(_:)`. SwiftLint custom rule will enforce. The renderer is free to convert to `CGFloat` for display.

**Why over alternatives:**
- *IEEE-754 floats with discipline*: works on Apple Silicon today, but `CityCore` is supposed to build on Linux (MVP `simulation-core` requirement). Cross-platform float determinism is a footgun.
- *Decimal*: overkill, slow, awkward for vector math.
- *Q15.16 fixed (Int32 with 16 fractional bits)*: less head-room than 1/4096-of-tile; for a 300-tile world the chosen scale gives 5+ decimal-equivalent digits inside a tile and we never approach the integer overflow ceiling.

CI determinism gate: run a 10-minute (6000-tick) archipelago scenario on macOS and Linux runners, assert byte-identical `World` Codable output.

### D8. Shipyard as a producer-building; Ship as its output

Shipyards fit the existing producer/consumer pattern cleanly:

```
   Shipyard
   ├── footprint: 2×3, must straddle shore (≥1 land tile,
   │              ≥1 adjacent water tile)
   ├── consumes: wood (N), planks (M)
   ├── produces: Ship entity, spawned in the adjacent water tile
   │             at construction completion
   ├── construction time: long (catalog-tuned, ~10 min play)
   └── road-connected to receive its input goods via carriers
```

No new simulation primitive — a shipyard is a producer whose output is "spawn an entity" instead of "emit a stack of goods." This piggybacks on the buildings-and-construction state machine.

### D9. Ports — multi-tile shore building, sibling to warehouse

A port has:
- a **multi-tile footprint** (e.g. 2×3) that MUST satisfy a shore predicate: at least one tile of the footprint is a land buildable tile, and at least one tile is an adjacent water tile reserved as the ship anchor;
- a **goods buffer** structurally identical to a warehouse's `stored[Good: Int]` with the same capacity model;
- a **carrier face** on land — carriers reach it by road-adjacency to any land tile of the footprint;
- a **ship face** on sea — the reserved water tile is the dock; ships moor here.

Ports and warehouses are **siblings**. Both implement the same "goods buffer" interface in code (`GoodsBuffer` protocol or a `BufferKind` discriminator on storage queries — exact factoring left to implementation). They are not parent/child; "Port extends Warehouse" would entangle land-only warehouse logic with sea concerns.

The MVP carrier-targeting rule ("carrier delivers to nearest warehouse with capacity") generalizes to "carrier delivers to nearest goods-buffer with capacity." Existing scenarios for warehouse acceptance and rejection remain valid because Port satisfies the same buffer contract.

### D10. Save schema v2 with explicit migration

The save format bumps from v1 to v2. The migration framework foreshadowed in MVP D6 activates here for real:

```
   v1 (MVP)                 v2 (this change)
   ────────────             ──────────────────
   World {                  World {
     version: 1,              version: 2,
     map: TileGrid,           map: TileGrid,        // larger sizes OK
     buildings: [...],        layout: LayoutID,     // "single-island"
     roads: [...],            buildings: [...],     //   or "archipelago"
     carriers: [...],         roads: [...],
     warehouses: [...],       carriers: [...],
     stockpiles: ...,         goodsBuffers: [...],  // warehouses + ports
     ...                      ships: [...],         // NEW
   }                          routes: [...],        // NEW
                              ...
                            }

   Migration v1→v2:
     • version: 1 → 2
     • layout: "single-island"
     • warehouses → goodsBuffers (Warehouse kind)
     • ships: []
     • routes: []
```

A v1 save loads, plays, and re-saves as a v2 save with no ships, no routes, no ports, and the existing carrier/warehouse economy intact. Players who started on MVP never lose progress.

JSON remains the v0 wire format (per MVP D6); binary encoding remains a separate, future optimization decision.

### D11. Route validation at authoring time, not at runtime

Land-intersection checking is done by `CityCore` **when the player commits a waypoint or saves a route**, not per-tick. A route in `.active` state is guaranteed by construction to be navigable.

If the world changes such that a previously-valid route is now invalid (a new building reclaims a tile, a port is demolished), the route transitions to `.broken` and any ships currently running it transition to `.returning`, heading back to the last valid port they visited.

**Validation rules** (the authoring API must enforce):
1. Each `.sea` waypoint position MUST lie on a water tile.
2. Each line segment between consecutive waypoints MUST NOT cross any non-water tile. Tested by sampling the segment at sub-tile resolution and rejecting on first land hit.
3. Each `.port` waypoint MUST reference an existing port; deleting a port that is referenced by an active route is allowed but transitions the route to `.broken`.
4. A route MUST contain at least two `.port` waypoints (otherwise there is nothing to do).

### D12. Behavior on edge cases (the autopilot table)

| Event | Behavior |
|---|---|
| Player demolishes a port mid-route | Route → `.broken`. Ship in transit → `.returning` to last valid port; on arrival → `.idle`. |
| Player demolishes shipyard that built a ship | Ship is unaffected; shipyard is its birthplace, not its home. |
| Ship docked, port full (cannot unload) | Wait at dock up to `dockTimeout` ticks, then skip the unload and advance. |
| Ship docked, port empty (cannot load) | Same: wait up to `dockTimeout`, then skip the load and advance. |
| Route edited while ship is between waypoints i and i+1 | Ship recomputes: if its previous "next" waypoint still exists, continue; else jump to nearest *upcoming* waypoint by route index. If route is empty or invalid, ship → `.returning`. |
| Two ships on the same route catch up | They overlap visually — no collision in sim. Renderer applies a small visual offset for clarity if same-tile. |
| Save loaded with a ship mid-segment | Position, heading, waypoint index, and cargo are all in the snapshot. Ship resumes exactly. |

### D13. Renderer additions

- **Ship sprites** are `SKSpriteNode`s positioned by converting `Fixed2D` to a `CGPoint` per render frame. The sprite texture is selected from a set of 8 pre-rendered facings by quantizing the snapshot heading to the nearest of N/NE/E/SE/S/SW/W/NW; the chosen texture is swapped in on facing change (no `zRotation` interpolation — see D16). Sub-tile *position* interpolation between snapshots (already a thing for carriers) extends to ships.
- **Route polylines** drawn as `SKShapeNode` overlays in a dedicated layer above terrain, below buildings. Render only when a route is selected or in route-authoring mode (avoids overdraw clutter).
- **Sea-tile shimmer** is already coming via `add-terrain-and-building-animations`. No new work here.
- **Route-authoring mode** is a UI mode in `CityUI` that overlays a SwiftUI affordance on the SpriteKit world. Tap-to-place waypoints; long-press a placed waypoint to delete; tap a port to add a stop; "Configure manifest" sheet opens for each port stop. Live land-intersection feedback colors invalid segments red.

### D14. Tests we owe (the scenario backlog)

Every `#### Scenario:` in the new and modified specs becomes a `swift-testing` test (per MVP D13). Concentrated test areas:

- `Fixed` arithmetic: round-trip Codable, monotonic addition, identical results across macOS/Linux runners (the determinism gate).
- Ship integration: arrival-epsilon detection, waypoint advancement, state transitions.
- Route validation: every rule in D11 has at least one positive and one negative test.
- Manifest execution: each verb under each port-state condition (full, empty, partial).
- Port goods-buffer behavior: identical to existing warehouse scenarios, replayed against a port.
- Save migration: a fixture v1 save loads, plays N ticks, re-saves; v2 schema present; world is byte-identical to a fresh single-island v2 game after the same input sequence.
- Deadlock policy: dockTimeout fires, ship advances, route survives.
- Edge cases from D12 each get a scenario.

Diff-cover applies as in MVP: every changed line in `CityCore` must be covered.

### D15. Asset organization — depend on the prerequisite atlas-layout change

This change does NOT migrate sprites into atlases on its own. That migration lives in the standalone `add-sprite-atlas-layout` change, which is a hard prerequisite. All new sprite content this change introduces (ship, port, shipyard PNGs) is written directly into the atlas-layout structure that the prerequisite establishes:

```
   Resources/
     Terrain.atlas/      (provided by add-sprite-atlas-layout, no change here)
     Buildings.atlas/    + building-port-{n,s,e,w}*.png       (24 new)
                         + building-shipyard-{n,s,e,w}*.png   (24 new)
     Units.atlas/        + ship-{n,ne,e,se,s,sw,w,nw}-{0,1}.png (16 new)
```

**Why split atlas migration into its own change rather than bundling here:**
- The atlas migration is a pure refactor (no behavior change, no new gameplay). Bundling it with archipelago would conflate ~30 PNG moves and a SpriteAtlas rewrite into the same PR review as the most architecturally significant gameplay change in the project. Splitting keeps each change reviewable on its own terms.
- The atlas-layout change is cheap to write and ship; it removes friction from every future change that adds sprites.

The `sprite-asset-pipeline` capability that the atlas-layout change introduces is extended in this change with: the ship sprite grammar (8 facings × 2 frames), the shore-building grammar (4 cardinal orientations × {idle, constructing×3, operational×2}), and explicit catalog entries for the 64 new PNGs (so the asset-presence check from atlas-layout fires if any are missing).

### D16. Pre-rendered facings, snap-not-rotate (Approach B), separate orientation variants for shore buildings

**Ship sprites: pre-rendered 8 facings, snap.** The renderer selects a sprite from 8 pre-rendered facings (N/NE/E/SE/S/SW/W/NW in *world* coordinates, which map to 8 distinct iso silhouettes) by quantizing the ship's `Fixed` heading to the nearest facing index. Texture swap happens at facing-change boundaries; `zRotation` is always zero on ship sprites. Position still interpolates sub-tile between snapshots for smooth motion.

**Why over free `zRotation` rotation:**
- The existing art DNA (walker has 4 pre-rendered iso facings, all buildings are hand-pixeled iso) requires that ships also be drawn from iso perspective. A single top-down sprite rotated via `zRotation` would clash visually with iso buildings sitting next to it ("Excel pivot table sailing past your sawmill").
- This matches the genre tradition (Caesar III, Anno 1602, Pharaoh).
- 8 facings gives 45° heading resolution — visible snap on a 32-px sprite but not jarring; can lift to 16 facings post-MVP if playtest reveals it as a problem.

**Wake is bundled into the ship frame animation** (the 2-frame cycle includes sail flutter + wake bob in the same sprite). Splitting wake into a separate sprite drawn underneath the hull is post-MVP polish.

**Shore-building sprites: 4 cardinal orientation variants.** Ports and shipyards straddle land + water. The portion of the sprite that overlaps water tiles must visually be water (pier extending out, dock pilings, etc.) and the portion overlapping land must visually be land (warehouse body, road approach). This is too sprite-specific to handle via renderer logic — it MUST be authored into the sprite. Each shore building therefore ships with 4 sprite variants, one per cardinal direction the water side faces (`n`, `s`, `e`, `w`):

```
   building-port-n-*    water side is north (top of footprint is water)
   building-port-s-*    water side is south (bottom of footprint is water)
   building-port-e-*    water side is east  (right of footprint is water)
   building-port-w-*    water side is west  (left of footprint is water)
```

At placement time the sim computes the building's `landFace`/`seaFace` tile classification (from `buildings-and-construction` shore-placement rule, already specified). At render time the renderer derives the cardinal direction by comparing the centroid of the sea-face tiles to the centroid of the land-face tiles, then selects the matching sprite variant.

**Why 4 cardinal variants and not 8:**
- Building footprints are axis-aligned rectangles on the tile grid. The water side can only be in one of 4 cardinal directions for a rectangular footprint. Diagonal water orientations (NE, NW, etc.) would require non-rectangular footprints, which the buildings-and-construction spec does not support.

**Why not derive sprite asymmetry dynamically at render time (e.g., flip horizontally for `w` vs `e`):**
- Asymmetric features (cranes, dock bollards, building entrances) don't flip cleanly. Authoring 4 variants is ~4× the artist effort but avoids "the entrance is now on the water side because we flipped" bugs.

## Risks / Trade-offs

- **Determinism risk** from continuous-position math. Mitigation: `Fixed` type, float ban in tick code, CI determinism gate against Linux.
- **Renderer load** from many sprites (ships, route overlays, atlas-bound sprite count). Mitigation: cull off-screen ships (existing pattern), render route polylines only on selection/authoring, atlas categorization from the prerequisite change reduces draw-call state changes.
- **UX complexity** of route authoring is the biggest unknown. Mitigation: ship a minimal authoring flow first (tap-to-place, two verbs), iterate based on play.
- **Save migration bugs** are particularly costly because they hit existing players. Mitigation: fixture-based v1 saves in CI, mandatory test coverage of every migration step.
- **Asset volume** grows by ~64 PNGs in this change (16 ship + 24 port + 24 shipyard). Mitigation: procedural generation in `scripts/generate-sprites.swift` keeps the asset cost mostly in generator code, not hand-pixeled art. Per-orientation shore-building variants are the largest asset-cost decision; explicitly chosen in D16 over the alternative of dynamic flipping.
- **Scope creep** toward specialization. Mitigation: this change explicitly defers specialization; resist the urge to bundle it.
- **Sequencing risk**: this change has a hard dependency on `add-sprite-atlas-layout`. If that change slips, this one cannot start implementation. Mitigation: atlas-layout is a small, low-risk refactor and should land fast.

## Migration plan (deployment)

- Land `add-archipelago-and-sea` in a single squashed feature line; do not split across releases (would require a v1.5 schema, which we are avoiding).
- Implementation milestones (see `tasks.md` when written):
  - M1: `Fixed` type + determinism CI gate.
  - M2: Continuous-position entity scaffolding in CityCore + snapshot round-trip.
  - M3: Route entity + validation rules + manifest verbs (no UI, headless).
  - M4: Port and Shipyard buildings, goods-buffer generalization.
  - M5: Ship entity, per-tick integration, state machine.
  - M6: v1→v2 save migration.
  - M7: Renderer (ship sprites, rotation, route polylines).
  - M8: UI route-authoring mode.
  - M9: Polish, scenario test sweep, determinism gate green.

`tasks.md` itself is left for the next pass — the user has not yet committed to implementation, and writing tasks before requirements are locked is premature.
