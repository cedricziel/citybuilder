## Why

Buildings cost money. That's the entire construction economy today. The goods system runs alongside it — sawmills make planks, warehouses store them — but goods never gate building placement. A player with infinite money and zero infrastructure can place a town's worth of buildings instantly; the simulation has no opinion.

Anno-likes earn their identity from a different loop: build → produce → consume → build. The first lumberjack hut consumes wood that you don't yet have, so you place it free; once it's running, planks become cheap and houses become possible; once houses are running, gold flows and bigger things unlock. The economic ladder *is* the game.

This change adds construction material costs to the catalog and enforces them at placement time. It builds on `add-island-hud-overlay`'s per-island stockpile aggregate (you can only build with goods stored on the same island) and surfaces the per-good cost in the placement ghost preview — red highlight when you're short. Phase 1 ships REJECT-only behavior: insufficient materials = no placement. The follow-up `add-construction-stalls` adds the hybrid "stall if production exists" experience.

## What Changes

- `BuildingSpec` gains `materialCost: [Good: Int]`. (`buildings-and-construction` modified.)
- The catalog populates costs per kind (see Q1 starter table in design D2). Roads are explicitly material-free; town center is also free (starter building).
- `World.canPlace(_:at:)` extends with a third validation pass after terrain + occupancy: the island's `IslandSummary.stockpile` (from `add-island-hud-overlay`) MUST contain enough of each required good. The new rejection reason is `.insufficientMaterials([Good: Int])` carrying the shortfall per good. (`buildings-and-construction` modified.)
- `World.applyPlace` deducts materials from warehouses + ports on the same island following a deterministic rule: cheapest road-distance first, breaking ties by ascending `EntityID`. Partial withdrawals across multiple warehouses are allowed when no single warehouse has enough. (`warehouses-and-logistics` modified.)
- New `WorldEvent.materialsDeducted(building:cost:)` emitted at placement so the audio layer can flag it later. (`world-events` modified.)
- Town center is seeded with starter inventory at world-gen — **4 wood + 2 planks** — so the player can place the first lumberjack hut (cost: 2 wood) and start the chain. (`buildings-and-construction` modified.)
- The ghost preview (`GameSession.ghostState`) extends with `costBreakdown: [Good: (need: Int, have: Int)]`. The renderer's ghost overlay shows the cost text below the building footprint preview, with the per-good label in red when `have < need`. (`rendering-2_5d` modified.)
- `PlacementResult` enum gains the `.rejected(.insufficientMaterials)` case alongside the existing terrain / occupancy rejection reasons.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `buildings-and-construction`: `BuildingSpec.materialCost`, placement validation extended to check it, town center starter inventory, deterministic material-deduction rule.
- `warehouses-and-logistics`: cross-warehouse partial withdrawal API used by placement. Existing producer→warehouse flow unchanged.
- `rendering-2_5d`: ghost preview shows per-good cost with red-on-short highlighting.
- `world-events`: new event case `materialsDeducted` for downstream observers.

## Impact

- **CityCore** — `BuildingSpec.materialCost` is a new struct field with default empty (== free). Catalog entries updated for each building. `World.canPlace` extends with one more check. `applyPlace` extends with a multi-warehouse deduction pass. `PlacementResult.rejected` gains a case. `WorldEvent` gains a case.
- **CityUI** — `GameSession.ghostState` gains the cost breakdown. `GhostPreview.valid` already exists; rather than collapsing to a single bool, the renderer reads the breakdown directly so it can color individual goods.
- **CityRender2D** — `IsoWorldScene` ghost overlay extends with a SwiftUI-rendered chip strip showing the cost. Or: the ghost-preview text already lives in CityUI; cleanest is to render the cost row in the CityUI HUD when a build tool is armed, not in the SpriteKit scene.
- **CityPersistence** — no save-format change. `BuildingSpec.materialCost` is static catalog data; saves continue to encode building IDs + states only.
- **CLI** — the headless runner already supports placement via commands. Tests gain seeded starter inventory in fresh-world fixtures.
- **Determinism** — material deduction must be deterministic across replays. The rule (cheapest road-distance first, then ascending EntityID) is deterministic.
- **Gates on** — `add-island-hud-overlay` for the per-island stockpile aggregate that `canPlace` consults. Without it, this change has no clean way to scope "do I have wood" to "wood on this island."
- **Performance** — material-availability check is O(warehouses on island) per placement validation. Placement is a low-frequency event (player input, not per-tick). Within budget.
- **No new third-party runtime dependencies.**
