## Context

Post-`add-build-materials-cost`, placement is binary: if the materials are in a warehouse on the island, you can build; if not, you can't. That makes the game punishing for new players and unrewarding for veterans (who already know the production loops and don't want to wait at the build palette).

Caesar III and Anno 1602 both solved this with stalled construction: the player places the building, carriers fetch the materials, and the construction site starts ticking once everything has arrived. The simulation continues running the whole time; the player can place the next building immediately.

The mechanics fall into three pieces:

1. **Allow placement when production exists.** Even if the warehouse cupboard is bare, if a producer on the island makes the needed good, the placement is queueable.
2. **Construction site as a goods consumer.** A new carrier mission type targets the construction site, drawing from warehouses on the same island.
3. **Building lifecycle nuance.** "Constructing" today means "building progress is happening." After this change it splits: "waiting for materials" (no progress) vs. "actively building" (progress).

## Goals / Non-Goals

**Goals:**

- Player can queue a sawmill the moment they have a running lumberjack hut, regardless of current wood stocks.
- Construction sites pull materials via the existing carrier system; no new entity class, just a new mission type.
- Building lifecycle stays simple: still `placed → constructing → operational`, but the constructing substate distinguishes waiting from actively-building.
- Replay determinism preserved: stalled construction has no new non-determinism sources.

**Non-Goals:**

- Cross-island delivery (ships carrying materials between islands). Out of scope; only same-island delivery participates.
- Partial-arrival incremental construction (e.g. tick rate scales with delivery completeness). Phase 1: all-or-nothing — waiting until 100% delivered, then full-rate construction.
- Visible construction-material counter on the building (e.g. "3/4 planks delivered"). The waiting badge is sufficient; the player can tap to inspect for detail.
- Construction-site capacity. We accept all materials carriers can deliver; the building's `materialsDelivered` doesn't have an upper bound beyond `materialCost`.
- Cancel-and-refund of in-progress construction. Demolition mid-wait returns the building tile; refund policy stays whatever B + future demolition refund change decides.

## Decisions

### D1. Substate via a new `ConstructionState` field, not enum nesting

```swift
public struct Building: Hashable, Codable, Sendable {
    // ... existing fields ...
    public var state: BuildingState              // unchanged: planned | constructing | operational
    public var constructionState: ConstructionState  // new
    public var materialsDelivered: [Good: Int]   // new; only meaningful while state == .constructing
}

public enum ConstructionState: String, Codable, Sendable {
    case actively       // ticksSincePlacement advances each tick
    case waitingForMaterials  // ticksSincePlacement does not advance
}
```

The substate field is meaningful only while `state == .constructing`. Once the building flips to `.operational`, the field is ignored (legacy value persists in saves for forensics).

**Alternatives considered:**

- *Nest the substate inside `BuildingState`:* `case constructing(ConstructionState)`. Tempting but breaks BuildingState's `Hashable` synthesis in subtle ways and forces every existing match to handle the substate. The orthogonal field is simpler.
- *Track waiting state on `World.constructionStateById: [EntityID: ConstructionState]`.* Rejected — splits Building data across two collections. The field is cheap; keep it on Building.

### D2. canPlace allow rule: "warehouses OR producers can supply"

After the existing terrain + occupancy + (Phase B's) warehouse-materials check, this change adds a producer-availability fallback. The full rule is:

```
For each (good, amount) in materialCost:
    let inWarehouses = islandStockpile[good] or 0
    let inProducers  = doesAnyProducerOnIslandMake(good)   // boolean

    if inWarehouses >= amount:
        ok — warehouse fully covers this good
    elif inWarehouses + (inProducers ? ∞ : 0) >= amount:
        ok — partial deduct now; carriers will deliver rest
    else:
        SHORT — placement rejected for this good

If all goods are ok, placement is allowed.
If any good is SHORT, placement is rejected.
```

The boolean `doesAnyProducerOnIslandMake(good)` looks up the production catalog: for each producer on the island in `.operational` state, does the producer's recipe output include `good`? This is a per-island scan and cheap; the result feeds back into the ghost preview's status state too.

**Alternatives considered:**

- *Just always allow placement; if you can never get the materials, the building sits forever.* Rejected — surprising player experience. Strict "production exists" gate gives a clean "this is impossible" rejection.
- *Allow placement only when warehouses + production can fulfill within N ticks.* Rejected — too clever, too restrictive. The current rule "can be supplied eventually" is sufficient.
- *Include constructing producers too (not just operational).* Tempting (the player should be able to chain construction). Phase 2 of this change. Phase 1 only counts operational producers for simplicity.

### D3. Carrier mission: deliverToConstructionSite

```swift
public enum Carrier.Mission: Sendable, Equatable, Codable {
    case deliver(good:amount:fromProducer:toWarehouse:)        // existing
    case retrieve(good:amount:fromWarehouse:toConsumer:)       // existing
    case deliverToConstructionSite(good:amount:fromWarehouse:toBuilding:)  // new
}
```

Carrier spawn logic is generalized: at the end of every tick, `spawnCarriersFromProducers` first checks for waiting construction sites on each producer's island and prioritizes deliveries to sites over deliveries to warehouses. Without this priority, a steady production stream would always route to warehouses, leaving construction sites starved.

Priority rule: *if a construction site is short on a good this producer makes, deliver to the site instead.* Construction takes precedence over warehouse fill.

**Alternatives considered:**

- *Round-robin between sites and warehouses.* Rejected — round-robin is non-deterministic without a counter, and adding a counter is more state. Strict priority is simpler.
- *Construction-site delivery from the warehouse closest to the site, not from the producer directly.* Reasonable refinement. Phase 1 keeps producer→site routing; Phase 2 may add warehouse→site routing for cases where the producer is far from the site.

### D4. Apply place: partial deduction + waiting state

```swift
private mutating func applyPlace(kind:anchor:events:) {
    // (existing canPlace + economy.deduct money cost)
    let cost = catalogSpec.materialCost
    let availableNow = islandStockpileAvailable(island: islandFor(anchor), goods: cost.keys)

    // Deduct as much as available now.
    var delivered: [Good: Int] = [:]
    for (good, amount) in cost {
        let take = min(amount, availableNow[good] ?? 0)
        deductFromIslandWarehouses(good, amount: take)
        delivered[good] = take
    }

    let isWaiting = delivered.contains { $0.value < cost[$0.key] ?? 0 }
    let building = Building(
        kind: kind,
        state: .constructing,
        constructionState: isWaiting ? .waitingForMaterials : .actively,
        materialsDelivered: delivered,
        ...
    )

    if isWaiting {
        events.append(.constructionWaitingForMaterials(
            building: id,
            missing: cost.compactMapValues { /* per-good shortfall */ }
        ))
    } else {
        events.append(.materialsDeducted(building: id, cost: cost))
    }
}
```

When carriers later arrive at the site, `applyCarrierArrival` for the new mission type increments `materialsDelivered`. After each increment, if delivered now satisfies cost, the substate flips to `.actively` and a `constructionStarted` event fires.

### D5. Tick-time gating: waiting buildings don't advance

```swift
private mutating func advanceBuildings(events: inout [WorldEvent]) {
    for (id, building) in buildings where building.state == .constructing {
        // NEW: skip waiting buildings — they do not advance.
        guard building.constructionState == .actively else { continue }

        var updated = building
        updated.ticksSincePlacement &+= 1
        let spec = BuildingCatalog.spec(for: building.kind)
        if updated.ticksSincePlacement >= spec.buildDurationTicks {
            updated.state = .operational
            events.append(.constructionCompleted(...))
        }
        buildings[id] = updated
    }
}
```

A building that's been waiting 200 ticks for the last plank to arrive, then receives it, will *not* skip ahead — it starts construction normally at tick 0 of `ticksSincePlacement` (which is whatever value advanceBuildings left it at, which is 0 since it never advanced). Just `buildDurationTicks` from now it's operational.

**Alternatives considered:**

- *Allow ticksSincePlacement to advance during wait, just hide the building until materials arrive.* Rejected — the building's already-visible on the tile (with the waiting badge), and the timer should reflect "actually building" time.
- *Time-warp progress on material arrival.* Rejected — no useful gameplay effect; the player just waited for materials.

### D6. Ghost preview status: blocked vs. queueable vs. ok

`costBreakdown` entries gain a status:

```swift
public enum CostStatus: Sendable, Equatable {
    case ok        // have >= need
    case queueable // have < need, but producers on island make this good
    case blocked   // have < need and no producers can supply
}
```

Chip rendering:
- `.ok` → default text color
- `.queueable` → orange text, "queue OK" suffix
- `.blocked` → red text, "blocked" suffix

If any good in the breakdown is `.blocked`, the placement is rejected (the existing red ghost overlay applies). If all goods are `.ok` or `.queueable` (some queueable, some ok), placement is allowed — the building enters waiting state if any good is `.queueable`.

**Alternatives considered:**

- *Just `.ok | .insufficient`; don't visualize the distinction.* Rejected — robs the player of the most important new gameplay information ("I CAN place this if I'm OK waiting").
- *Per-good color only, no text suffix.* Worth iterating on. Orange-only might be enough.

### D7. Determinism

Stalled construction adds zero non-determinism if:
- Carrier mission resolution uses the existing stable sort.
- Construction site priority in `spawnCarriersFromProducers` is a deterministic check on Building.constructionState.
- materialsDelivered increments only happen on `applyCarrierArrival`, which is per-tick deterministic.

The two new events (`constructionWaitingForMaterials`, `constructionStarted`) follow the stable event-sort rule. Replay equality holds.

### D8. Visual: waiting badge

A small 16×16 overlay sprite drawn on the top-right of the building tile while in `.waitingForMaterials`. Procedural pixel-art clock face, generated by `scripts/generate-sprites.swift`. Stored under `Resources/Buildings.atlas/overlay-waiting-materials.png`.

The badge sits at the building's `position + (footprint.width/2, footprint.height/2)` offset, with `zPosition` above the building base. Easy to also reuse the badge for other "waiting" states (sawmill out of wood, etc.) in a future change.

## Risks / Trade-offs

- **[Carrier loop now considers two consumer types]** → Mitigation: priority rule (sites first) is deterministic and well-tested. Unit tests cover both code paths.
- **[Player builds a city of waiting buildings and never produces anything]** → That's a gameplay failure mode, not a sim failure. Mitigation: the orange "queue OK" preview cue, plus the existing `productionStalled` audio (Phase 2), make the failure mode visible without crashing the loop.
- **[Players don't notice they're waiting]** → Mitigation: the waiting badge + Inspector showing per-good delivery progress. Subtle, but discoverable.
- **[Save migration]** → `Building.materialsDelivered: [Good: Int]` defaults to empty in pre-v3 saves. Buildings loaded with `state == .constructing` and empty `materialsDelivered` get re-derived: assume their `materialCost` was fully paid at v2 placement, so seed `materialsDelivered = materialCost` and set `constructionState = .actively`. That's the most player-friendly migration (they don't lose progress).
- **[Carrier-routing complexity]** → Mitigation: spawn logic stays in one function (`spawnCarriersFromProducers`) with a new branch. Roughly +20 lines.

## Migration Plan

`Building.materialsDelivered` and `Building.constructionState` default to `[:]` and `.actively` respectively. v2 saves loading into v3:
- For each `Building` with `state == .constructing` in a v2 save, the migration seeds `materialsDelivered = BuildingCatalog.spec(for: building.kind).materialCost` and `constructionState = .actively`. This treats the v2 building as "already paid in full," because that's exactly what `applyPlace` did in v2.
- For each `Building` with `state == .operational`, the fields stay at defaults; the values never get read.

Rollback is a clean revert; v3 saves cannot be loaded by a pre-revert binary (which is the usual save-bumps-and-can't-come-back rule).

## Open Questions

- **Should the waiting badge animate?** Phase 2 audio gives sonic feedback; the visual could pulse subtly. Tasteful and free if SpriteAnimation supports it.
- **Should construction-site deliveries from warehouses (not producers) be supported?** Phase 1 routes producer→site directly. Caesar III routed warehouse→site. The warehouse route makes more sense when production has gotten ahead of consumption; site→producer can deadlock when the producer is far from the site. Possibly Phase 2 of this change or a polish follow-up.
- **What if the player demolishes a waiting building?** Materials already delivered (in `materialsDelivered`) are lost or refunded? v0: lost. Future demolition refund spec handles this.
- **Should `canPlace` consider operational *and* constructing producers when checking the queueable path?** Tighter rule: only operational. Looser rule: also constructing (so you can chain "place lumberjack, then immediately queue sawmill, then immediately queue warehouse"). v0: operational only. Worth iterating after playtest.
