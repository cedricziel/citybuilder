## Why

`add-build-materials-cost` ships REJECT-only behavior: if the island doesn't have the materials in a warehouse right now, you can't place the building. That's the simple rule but it's harsh — the player must babysit production, wait for warehouses to fill, and only then walk back to the build palette. Caesar III and Anno solved this with **stalled construction**: place the building anyway and let carriers deliver materials when they're ready. The construction site itself becomes a goods consumer.

This is the hybrid Q2 behavior:

- If the island has the materials in a warehouse right now → instant deduction, normal construction (Phase B's behavior, unchanged).
- If the island doesn't have them in a warehouse but has producers that *make* them → place the building stalled; carriers deliver materials over time; construction starts ticking once everything has arrived.
- If the island has neither → reject (Phase B's behavior, unchanged).

The win is player-friendliness: you can queue a sawmill the moment your lumberjack starts running, and the sawmill will build itself as soon as enough wood is hauled to the site. The cost is real new simulation: construction-site goods consumption, a new carrier mission type, and a building state nuance (.constructing means "waiting" sometimes and "actively building" sometimes — those need to be distinct in the rendering).

## What Changes

- `Building` gains a `materialsDelivered: [Good: Int]` field tracking how much of each required good has arrived at the construction site. (`buildings-and-construction` modified.)
- `BuildingState` gains a `.waitingForMaterials` substate of `.constructing`. Buildings in this state do NOT increment `ticksSincePlacement`; only buildings whose `materialsDelivered` is `>= materialCost` for every good advance. (`buildings-and-construction` modified.)
- `World.canPlace(_:at:)` extends with a fourth allow path: if the island's *production graph* can eventually supply the missing goods (any producer on the island has the missing good in its recipe outputs), placement is allowed even when warehouses are momentarily short. The rejection path now only fires when neither warehouses nor any producer can supply. (`buildings-and-construction` modified.)
- `World.applyPlace`:
  - If warehouses have enough → deduct instantly (Phase B behavior). The building's `materialsDelivered` is seeded equal to `materialCost`, and the building enters `.constructing` normally.
  - If warehouses lack some → deduct what they have, leave the rest in `materialsDelivered` as a partial. The building enters `.constructing` but in the `.waitingForMaterials` substate.
- New `Carrier.Mission.deliverToConstructionSite(good:amount:from:to:)` mission. A construction site behaves as a goods *consumer*; the existing producer→consumer carrier spawn logic generalizes to target construction sites that are short on materials. (`warehouses-and-logistics` modified.)
- New `WorldEvent.constructionWaitingForMaterials(building:missing:)` emitted on placement when the building enters the waiting substate. (`world-events` modified.)
- New `WorldEvent.constructionStarted(building:)` emitted on the tick the building transitions from waiting → actively-constructing (i.e., when `materialsDelivered` first satisfies `materialCost`). (`world-events` modified.)
- Renderer additions: a "waiting for materials" badge overlaid on the building tile while in the substate (small clock-face icon, top-right of the footprint). Existing constructing sprite stays. (`rendering-2_5d` modified.)
- Renderer additions: the ghost preview's `costBreakdown` row gains a tertiary state — when `have < need` BUT producers on the island make this good, the chip shows orange (rather than red) with text "queue OK". The CityUI surfaces this as "Materials will be delivered". (`rendering-2_5d` modified.)

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `buildings-and-construction`: new `.waitingForMaterials` substate, `Building.materialsDelivered`, `canPlace` gates differently on island production graph, `applyPlace` may partially-deduct and start waiting.
- `warehouses-and-logistics`: new carrier mission targeting construction sites; carrier spawn loop considers construction sites as consumers in addition to warehouses (existing producer→warehouse path unchanged).
- `world-events`: two new events (`constructionWaitingForMaterials`, `constructionStarted`).
- `rendering-2_5d`: waiting badge overlay, ghost preview orange / red distinction.

## Impact

- **CityCore** — `Building` gains one field. `BuildingState` gains a substate (likely modeled as `.constructing(.actively)` / `.constructing(.waitingForMaterials)` via an enum nesting, or `Building.constructionState: ConstructionState` alongside the existing `state: BuildingState`). Three new pieces of tick-time work: a check at the top of `advanceBuildings` to skip waiting buildings, a check in `spawnCarriersFromProducers` to also consider construction sites as targets, and an `applyCarrierArrival` branch for the new mission type.
- **CityUI** — `GameSession.ghostState()`'s `costBreakdown` gains a third color state via a derived `status: .ok | .queueable | .blocked` per good. CostBreakdownView grows a status-aware chip color.
- **CityRender2D** — small badge sprite added to the catalog (`overlay-waiting-materials.png`, ~16×16 procedural pixel art). Rendered as a child node of the building during the waiting substate.
- **CityPersistence** — `Building.materialsDelivered` is `Codable` (just `[Good: Int]`). Backwards-compatible: missing in old saves → empty dict → treated as zero delivered. Whether that's the desired migration is a small decision (see Open Questions).
- **CityAudio** — no changes here. Phase 2 audio (`enrich-audio-world`) will eventually bind `constructionWaitingForMaterials` and `constructionStarted` to sounds. Phase 1 leaves them silent.
- **Determinism** — carrier spawn for construction sites uses the same deterministic ordering as warehouse delivery (producer EntityID ascending → target EntityID ascending → good ordinal). No new replay risk.
- **Gates on** — `add-build-materials-cost` for the `materialCost` field, the `IslandSummary` aggregate, and the ghost-preview cost row this change extends. Without B, there's no "stall vs. reject" distinction to draw.
- **Performance** — construction-site-as-consumer adds one more dictionary iteration per producer tick; bounded by the number of operational producers per island. Well inside the per-tick budget.
- **No new third-party runtime dependencies.**
