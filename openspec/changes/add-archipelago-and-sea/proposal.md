## Why

The MVP locked the world to one fixed island. Anno's identity hinges on the loop that emerges *after* that: multiple islands, ships ferrying goods between them, and the player drawing trade routes by hand across open sea. This change adds that loop — multi-island world topology, sea transport, ports, and shipyards — in a single bundle, because each piece is degenerate without the others (ships without ports are nothing; ports without ships are warehouses on a beach; islands without ships are unreachable).

Two scoping decisions emerged from the explore-mode discussion that captured this proposal:

1. **Steering = autopilot only.** The player draws a polyline of waypoints once; the ship runs that route forever (with manual override of the route definition, but not of an individual voyage). This decision collapses runtime ship logic to a small integration loop and pushes all spatial expression to the authoring step.
2. **Economic specialization (climate-gated goods, neutral trader, etc.) does NOT ship in this change.** It moves to a follow-up `add-island-specialization` so the architectural lift here can be evaluated independently. This change delivers a multi-island world you can sail around with goods; the next change makes the second island *matter*.

## What Changes

- Broaden the world-terrain model: in addition to the MVP's single fixed island, the game SHALL support an `archipelago` world layout — multiple landmasses on a single rectangular tile grid (target: ~300×300 tiles), deterministic per-seed.
- Introduce **continuous-position entities** as a new motion model in `CityCore`. Land entities (carriers, citizens) remain integer-tile. Sea entities (ships) carry `(Fixed x, Fixed y, Fixed heading)` and advance per-tick by integration toward the next waypoint. Tile coordinates are unchanged; sea entities live in a parallel fixed-point space anchored to the same grid.
- Introduce a **`Fixed` numeric type** in `CityCore` and forbid `Float`/`Double` in tick-time ship code. Required for deterministic cross-platform builds.
- Introduce **Route** as a first-class persistent entity: an ordered list of waypoints (either a sea coordinate or a port reference) plus a per-port cargo manifest. Routes are decoupled from ships — they outlive ships, can have zero or more ships assigned, and are editable while ships are en route.
- Introduce **Ship** as a new entity class assignable to a route. Per-tick: integrate position toward the next waypoint, advance the waypoint index on arrival, execute the manifest at port stops. State machine: `idle / sailing / docked / returning(.broken-route)`.
- Introduce **Port** as a new building kind with a multi-tile footprint that straddles shore (land tiles for road access + adjacent water tile for the ship anchor). Acts as a goods buffer like a warehouse, but accepts deposits and withdrawals from both carriers (land side) and ships (sea side).
- Introduce **Shipyard** as a new producer-building kind that consumes wood and planks and emits ship entities into an adjacent water tile.
- Generalize the producer/consumer carrier-targeting logic from "nearest warehouse" to "nearest goods-buffer" so existing land buildings deposit at ports as naturally as at warehouses.
- Bump save schema to v2 with an explicit v1→v2 migration. This is the first real exercise of the migration framework foreshadowed in MVP design decision D6.
- Renderer additions: ship sprites with heading-driven rotation, route polyline overlay, route-authoring UI mode (tap-to-place waypoints, port snapping, live land-intersection validation, manifest editing sheet).

## Capabilities

### New Capabilities

- `sea-transport`: Ship entity, Route entity, waypoint and manifest authoring rules, per-tick ship integration loop, port handoff semantics, ship state machine.
- `port-and-shipyard`: Port building (shore footprint, sea anchor, goods-buffer behavior on both faces). Shipyard building (producer of ships).
- `fixed-point-math`: A `Fixed` numeric type in `CityCore` with stable cross-platform semantics for continuous-position entities. Defines the float ban in tick code.

### Modified Capabilities

- `world-terrain`: relax "Fixed island map" to "deterministic per-seed world from one of two named layouts (`single-island`, `archipelago`)." Both remain byte-identical given a fixed seed.
- `buildings-and-construction`: add a shore-placement rule that permits footprints to straddle land + water under conditions used only by Port and Shipyard.
- `warehouses-and-logistics`: generalize carrier targeting and storage queries to operate against any goods-buffer building (warehouse OR port). Existing warehouse scenarios remain valid.
- `persistence-save-load`: introduce save schema v2 and a versioned migration mechanism. v1 saves load as `single-island` archipelago-of-one with no ships, no ports, no routes.
- `rendering-2_5d`: continuous-position sprite rendering with **pre-rendered facing selection** (8 facings, snap to nearest — *not* free `zRotation` interpolation), shore-building orientation derivation from `landFace`/`seaFace` tile classification, route polyline overlay, sea-tile shimmer integration (already coming from `add-terrain-and-building-animations`), route-authoring input mode.
- `sprite-asset-pipeline`: extend the naming grammar established by the prerequisite `add-sprite-asset-layout` change with two new sprite categories: ship sprites (8 facings × 2 frames, in `Units.atlas/`) and shore-building sprites (4 cardinal orientation variants per building kind, in `Buildings.atlas/`). The 4-orientation grammar applies to Port and Shipyard.

## Impact

- **New simulation systems**: ship integration, route execution, port handoff. Tick-time cost grows modestly — a handful of ships in an early archipelago game, tens in a mature one. Still well inside the 5 ms/tick budget on iPhone.
- **New entity class**: `Ship`. The existing `Carrier` is unchanged. The two are siblings, not parent/child; "moves goods" is a concept, not a base type.
- **Save format**: v2. The migration framework activates for real. Old v1 saves continue to load and play.
- **Renderer**: introduces continuous-position sprite math, sprite rotation by heading, and polyline drawing — none of which exist today. Manageable in SpriteKit; ships are `SKSpriteNode`s with `zRotation` driven by the snapshot.
- **UI**: route-authoring is a substantial new interaction surface (waypoint placement, port snapping, manifest sheet, route list view). The largest UX delta in the change.
- **No new third-party runtime dependencies.** Apple frameworks only, per MVP constraint.
- **Determinism risk**: continuous-position math is the first thing in the project that *could* drift across platforms. Mitigated by `Fixed` (Path B from the explore discussion) and a CI determinism test that runs the same archipelago save for N ticks on macOS and Linux and asserts byte-identical post-tick state.
- **Out of scope, intentionally deferred**:
  - Climate-gated goods and per-island specialization → `add-island-specialization`.
  - Procedural archipelago generation beyond a small hand-authored seeded layout set.
  - Pirates, naval combat, storms, weather.
  - AI competitor factions (Anno-style trading rivals).
  - Multiple cargo verbs beyond `loadUpTo` / `unloadUpTo` (no "wait until full," no conditional loads — open question, see design D6).
  - Free-rotation `zRotation`-based ship sprites (decided against; see design D16 — pre-rendered 8-facing snap is the art-coherent choice).
  - Separate wake sprites drawn under ship hulls (v0 bundles wake into the hull-frame animation; can split later if needed).
- **Asset additions** (under the post-atlas-layout structure provided by the prerequisite change):
  - Ship: 16 PNGs in `Units.atlas/` (8 facings × 2 frames, hull + bundled wake).
  - Port: 24 PNGs in `Buildings.atlas/` (4 cardinal orientations × {1 idle + 3 constructing + 2 operational} = 24).
  - Shipyard: 24 PNGs in `Buildings.atlas/` (same orientation × state × frame matrix as Port).
  - Total new sprite content: 64 PNGs, generated by extensions to `scripts/generate-sprites.swift`.

## Dependencies

- **Requires (must precede this change):**
  - `add-sprite-atlas-layout` to be archived. This change writes all new sprites directly into the atlas-layout structure that change establishes, and extends the `sprite-asset-pipeline` capability that change introduces. Sequencing also implies `add-terrain-and-building-animations` is already archived (it's the predecessor of `add-sprite-atlas-layout`).
- **Blocks (must precede those changes):**
  - `add-island-specialization`. The specialization change adds climate-gated buildings and goods that build on top of the multi-island world this change establishes.

## Open questions

These were surfaced during the explore session and are flagged for resolution before implementation begins, but do not block writing this proposal:

- **Manifest verbs:** Two verbs (`loadUpTo`, `unloadUpTo`) for v0? Or also `waitUntilFull`? Recommendation: two verbs, defer the third.
- **Procgen vs hand-authored archipelago at v0:** Hand-authored seeded layouts first, procgen as a follow-up change.
- **Fixed-point scale:** Implicit scale of 1/4096 tile (12 bits of subtile precision) feels right. To be confirmed in design.
