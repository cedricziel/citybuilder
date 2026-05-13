## Context

`BuildingSpec` defines `cost: Int64` (money), `upkeep: Int64`, `footprint`, `buildDurationTicks`, and (post-archipelago) `shorePlacement`. There's no concept of physical inputs to construction. `World.applyPlace` deducts money, sets the building to `.constructing`, and the per-tick `advanceBuildings` system increments `ticksSincePlacement` until the building flips to `.operational`. Materials live in the goods system but never feed back into the catalog.

`add-island-hud-overlay` introduces `WorldSnapshot.islandSummaries` — a per-island aggregate of warehouse + port + shipyard stockpiles. That's exactly the surface this change consults to ask "can I afford this building?" on the island the player is placing it on.

The carrier system already has the machinery to deduct goods from warehouses (`Stockpile.withdraw`). What's new here is calling that withdrawal from `applyPlace` — outside the per-tick carrier loop — with a deterministic rule for which warehouses contribute.

## Goals / Non-Goals

**Goals:**

- Every building (except road + town center) declares a material cost. The catalog encodes a sensible starter set.
- `canPlace` rejects when the island can't supply the materials. The ghost preview shows the cost per-good with the deficit highlighted.
- `applyPlace` deducts materials from the island's warehouses deterministically.
- Town center seeded with starter inventory so the player can bootstrap.
- Players can read "do I have enough" from the same HUD that `add-island-hud-overlay` introduces.

**Non-Goals:**

- Stalled construction. If you don't have the materials, you can't place. (`add-construction-stalls` follow-up.)
- Cross-island withdrawal via ships. The whole point of per-island scope is that ships ferry between islands; placement uses local stocks only.
- Demolition refunds in materials. v0 keeps demolition material-free (zero refund). Refining the refund policy is a separate scope decision.
- Tuning the starter recipes. The numbers in D2 are conservative and meant for first playtest. Iteration belongs in a polish change.
- Material costs for upkeep. Buildings still consume money for upkeep; they don't consume materials for upkeep (yet).
- Recipes that change with game state (research / tech tree). Static catalog.

## Decisions

### D1. Material cost as a `[Good: Int]` on BuildingSpec

```swift
public struct BuildingSpec: Hashable, Sendable {
    // ... existing fields ...
    public let materialCost: [Good: Int]   // default [:] = free of materials

    public init(..., materialCost: [Good: Int] = [:], ...) {
        // ...
    }
}
```

Dictionary-keyed by `Good` so adding a new good doesn't require a code change at every cost site — just append `(good, amount)` to the recipe. `Good` is already Hashable.

**Alternatives considered:**

- *Tuple list `[(Good, Int)]`.* Rejected — `Dictionary` has the right semantics (a good appears at most once) and `Hashable` synthesis Just Works on dictionaries.
- *Separate per-good fields (`woodCost`, `plankCost`, …).* Rejected — explodes with each new good.
- *A typed `ResourceCost` struct.* Premature. If the cost shape grows (e.g. cost-per-tile-of-footprint multiplier) we revisit.

### D2. Starter recipes

```
  Town Center      free               (player starts with one)
  Road             free               (player paints many; money cost only)
  Lumberjack Hut   2 wood             (entry point; wood comes from forest tile)
  Sawmill          4 wood + 1 plank   (forces some prior lumberjack production)
  Warehouse        2 wood + 6 planks  (mid-game storage; rewards planks chain)
  House            4 planks           (population unlock; pure planks demand)
  Port             8 wood + 6 planks  (late-game; gates archipelago expansion)
  Shipyard         12 wood + 8 planks (lategame; gates ship production)
```

Town center starter inventory: **4 wood + 2 planks**. Enough to place exactly one lumberjack hut (2 wood), leaving 2 wood + 2 planks — short of a sawmill (4 wood + 1 plank), so the player must wait for the lumberjack to run a few cycles before they can place the sawmill. That's the intended bootstrap pacing.

These numbers are first-pass and **want playtesting**. The catalog is a constant table, so tuning is a one-commit change.

**Alternatives considered:**

- *Roads cost 1 wood each.* Rejected — players paint many roads in a single placement gesture; charging materials per tile would make the painting flow miserable.
- *Town center starts with 100 of everything.* Rejected — defeats the bootstrap loop. Starter inventory exists to unblock the *first* placement, not the first hour.
- *Different starter amounts per layout (more for archipelago, less for single-island).* Premature. Same amount works; if archipelago starts feel cramped, tune later.

### D3. Material withdrawal: cheapest road-distance first, ascending EntityID tiebreak

When `applyPlace` deducts materials, it iterates the island's warehouses + ports sorted by:

1. Road-distance from the placement anchor to the warehouse anchor (shortest first).
2. Ascending `EntityID.raw` (ties).

For each good in the recipe, withdraw from the first-sorted warehouse up to `min(needed, warehouse.quantity(of:))`, then advance to the next warehouse if there's still a shortfall, until the need is satisfied.

If `canPlace` returned `.allowed`, the deduction is guaranteed to succeed — `canPlace` summed availability across all warehouses on the island before allowing placement.

```swift
private mutating func deductMaterials(
    cost: [Good: Int],
    forBuildingAt anchor: TileCoordinate,
    onIsland islandID: IslandID
) {
    let warehouses = islandWarehouses(islandID)
        .sorted {
            let dA = roadDistance(from: anchor, to: $0.anchor) ?? .max
            let dB = roadDistance(from: anchor, to: $1.anchor) ?? .max
            return dA != dB ? dA < dB : $0.id.raw < $1.id.raw
        }
    for (good, totalNeeded) in cost.sortedByGoodOrdinal {
        var remaining = totalNeeded
        for warehouse in warehouses where remaining > 0 {
            let take = min(remaining, stockpiles[warehouse.id]?.quantity(of: good) ?? 0)
            stockpiles[warehouse.id]?.withdraw(good, amount: take)
            remaining -= take
        }
    }
}
```

**Alternatives considered:**

- *Withdraw from a single warehouse only.* Rejected — fails when no single warehouse has enough but the island as a whole does.
- *Random / round-robin withdrawal.* Rejected — non-deterministic.
- *Cheapest road-distance only, no tiebreak.* Same road-distance happens (e.g. two warehouses equidistant from the anchor); ascending EntityID is the natural tiebreak the rest of the codebase already uses.

### D4. Placement preview UI

The ghost preview already exists (`GameSession.ghostState`). It returns a `GhostPreview { kind, tile, valid }`. We extend with `costBreakdown: [Good: (need: Int, have: Int)]?` (nil when the armed tool has no material cost, like road or inspect).

The CityUI HUD reads the breakdown and renders below the build palette: a horizontal strip of `(icon, "N/M")` chips. When `have < need`, the chip text turns red. When `have >= need`, normal color. When the tool has no material cost, the strip is hidden.

```
   Build palette: [house *armed*] [warehouse] [road] ...

   Materials needed:
   ⌗ planks  2/4    ← red, you're short
```

The SpriteKit ghost overlay (the tile-bounded translucent building sprite) is **unchanged** by this work. Cost validation reflects in the CityUI strip; geometry validation reflects in the existing scene-tinted ghost.

**Alternatives considered:**

- *Cost overlay drawn in the SpriteKit scene.* Rejected — text rendering in SpriteKit is awkward and the cost info is HUD-level, not world-level.
- *Cost overlay as a floating tooltip near the cursor.* Tempting on Mac (mouse cursor), bad on iPad (no cursor). HUD strip works on every platform.

### D5. Determinism

Material deduction is deterministic:
- Island sort order: by `IslandID` (stable per world-gen).
- Warehouse sort: road-distance (deterministic on the road graph), tiebreak ascending `EntityID`.
- Good iteration: a fixed enum ordinal (`Good.allCases` order matches the enum declaration).

Two replays of the same input sequence deduct materials in the same order and produce byte-identical `World` state. The new `WorldEvent.materialsDeducted` follows the stable event ordering rule from `world-events` (sort by primary `EntityID`, then case ordinal).

### D6. Town center starter inventory at world-gen

`IslandGenerator.generate()` already produces terrain. World-gen also seeds an initial town center per island (per `add-archipelago-and-sea` or by player choice — TBD by archipelago). When the town center is placed, its `Stockpile` is seeded with the starter contents.

The town center is itself a warehouse for purposes of withdrawal: it's a goods-buffer on the island, so the island's `IslandSummary.stockpile` includes the town center's starter inventory. Placing the first lumberjack hut deducts 2 wood from the town center.

After the lumberjack runs cycles, wood accumulates in the town center until a player-built warehouse can absorb it.

**Alternatives considered:**

- *Starter goods in a free-floating "treasury."* Rejected — the deduction rule operates on warehouses+ports. A treasury would be a new concept.
- *Town center is non-buffer; starter goods seed the first warehouse instead.* Rejected — players might not build a warehouse first. The town center is the only guaranteed building on a fresh world; it has to be where the starter pile lives.
- *No starter inventory; player must clear a forest tile by hand to bootstrap.* Tempting but: forest clearing emits `forestHarvested` events but doesn't spawn wood as a good (per current spec — forest is consumed by the lumberjack from the world, not by the player). The lumberjack chain needs the lumberjack to *exist*, which needs 2 wood, which needs the starter inventory.

## Risks / Trade-offs

- **[Recipe tuning is wrong on first ship]** → Mitigation: numbers are in a constant table; iteration is a one-commit change. Conservative starter (4 wood + 2 planks) lets the player place one building and immediately experience the loop, surfacing pain points fast.
- **[Multi-warehouse withdrawal corner cases]** → Mitigation: the rule is deterministic and short. Unit tests cover: single-warehouse fully-stocked, two-warehouses split, exact-zero edge, off-by-one shortfall.
- **[Town center demolition rebuilds]** → Mitigation: town center is non-demolishable in v0 (it's the bootstrap anchor). If demolishability is added later, that change handles starter-inventory-after-rebuild.
- **[Ghost preview lag]** → Mitigation: cost breakdown is computed from the snapshot's per-island aggregate. Snapshot updates per tick; cost breakdown updates per tick. The visible UI is at most 100 ms stale, well within human reaction time.
- **[Player frustration: "I can't even place a sawmill?"]** → Mitigation: the recipe is gentle (4 wood + 1 plank, not 20 + 10). The HUD's stocks chip makes the requirement glanceable. Stall in the follow-up change softens this further.
- **[Determinism risk from `Dictionary` iteration in cost loops]** → Mitigation: cost iteration uses `[Good: Int].sortedByGoodOrdinal`, which materializes a deterministic ordering. Spec scenario locks this in.

## Migration Plan

`BuildingSpec.materialCost` defaults to `[:]` for forwards compatibility. New saves include town center stockpile contents (which is just a `Stockpile`, already Codable). v1 saves (single-island, pre-archipelago) load with empty town center stockpile; the player's first build path becomes more limited but not impossible (the recipe applies to new placements; existing buildings on a loaded save stay where they are).

Future migration to add new building kinds with material costs is purely additive — old saves load fine; the new kinds simply aren't placed in those saves.

Rollback is a clean revert. Material costs are catalog data, not save data; removing them just relaxes placement validation.

## Open Questions

- **Should partial withdrawal split goods across warehouses by quantity (proportional)?** Current rule is greedy: take everything from the first warehouse, then move on. Proportional split is more "fair" visually (depletes warehouses evenly) but no gameplay reason today.
- **Refund on demolish?** Out of scope here. Likely: partial refund of money but zero material refund. Worth a separate small change.
- **Multi-island withdrawal once ports + ships exist?** Out of scope — placement is local-only by design. If a future change wants "ship goods from Island A to Island B to enable a build on B," that's a much bigger gameplay feature.
- **What if the player places a warehouse before the lumberjack hut produces wood?** They can't — warehouse costs 2 wood + 6 planks, which they don't have at start. Lumberjack first is the forced sequence. That's a feature; the tutorial UI should guide it.
