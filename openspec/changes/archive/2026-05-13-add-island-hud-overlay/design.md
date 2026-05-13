## Context

`HUDViewModel.apply(snapshot:)` reads two scalars: `economy.balance` and `totalPopulation`. The rest of `WorldSnapshot` — buildings, carriers, terrain — is consumed by the SpriteKit scene, not the HUD. Stockpiles aren't even in the snapshot; they live on `World` and the snapshot omits them entirely because the renderer never needed them.

`add-archipelago-and-sea` introduces `Island` records (connected components of buildable tiles) with stable `IslandID`, bounding box, and tile count. It does **not** add a name field or a per-island goods aggregate. Both are the natural extensions for this change.

The HUD is the only player surface that needs island-scoped goods data today. Carriers will eventually need it for cross-island routing, but that's `add-island-specialization`'s concern; for now the data lives in the snapshot purely for display.

## Goals / Non-Goals

**Goals:**

- Player can read "what's in stock on this island" without tapping a building.
- Player has a referent — a name — for each island so cross-island reasoning has a vocabulary.
- Camera-driven scope: HUD reflects whatever island the camera centers on. No manual island selector needed; sticky behavior covers the over-water case.
- Procedurally generated good icons consistent with the rest of the project's pixel-art aesthetic.

**Non-Goals:**

- Material costs on buildings. (`add-build-materials-cost` follow-up.)
- Construction stalls. (`add-construction-stalls` follow-up.)
- Per-warehouse drill-down. The HUD answers the global "do I have wood" question; the inspector answers "does *this* warehouse have wood."
- Manual island selector / pin-this-island UI. Camera-driven scope is sufficient; an explicit pin can land later if playtesting demands it.
- Climate band display. The archipelago change carries `climate: ClimateBand` but no gameplay reads it yet; the HUD ignores it for now.
- An always-visible global goods-across-all-islands aggregate. That's `add-island-specialization`'s problem — it only becomes useful when ships start trading.

## Decisions

### D1. Per-island aggregate computed at snapshot time, not stored on World

`WorldSnapshot.islandSummaries` is rebuilt every snapshot. The cost is O(buildings) per snapshot — the same order as the snapshot's existing per-building copy. Storing aggregates on `World` would mean updating them on every stockpile change, which is hot-path code; the snapshot is a cooler boundary.

The renderer pulls one snapshot per frame, so this runs at ~60 Hz. With a few thousand buildings worst case, that's still well under the 5 ms per-tick budget. (The HUD update is on the snapshot path, not the tick path, but the budget is comparable.)

**Alternatives considered:**

- *Cache aggregates on World, invalidate on stockpile change.* Rejected — too many hot-path mutations to invalidate cleanly. Recompute is simpler and within budget.
- *Compute aggregates lazily in `HUDViewModel`.* Rejected — splits the responsibility; the snapshot is the canonical "what does the UI see" payload.

### D2. Tile-to-island lookup via cached map

`WorldSnapshot.tileToIsland: [TileCoordinate: IslandID]` is built once when the snapshot is constructed (or, equivalently, derived from the existing `Island.bounds` + occupiedTiles check). Lookup is O(1).

For a 300×300 archipelago with say 4 islands averaging 1000 tiles each, the map has 4000 entries — 64 KB at most. Reasonable.

**Alternatives considered:**

- *Linear scan through `[Island]` doing bounds checks on every lookup.* Rejected — would make the HUD's camera-tracking path O(islands) per frame. Cheap today, expensive at 20 islands.
- *No map, just iterate `island.bounds` until containment hits.* Same as above. Bounds tests are cheap but lookups dominate as island count grows.

### D3. Island name = seeded pick from a 64-entry table indexed by island center

```swift
extension Island {
    static func name(for islandID: IslandID, bounds: TileRect, seed: UInt64) -> String {
        let center = (bounds.minX + bounds.maxX) / 2
        let centerY = (bounds.minY + bounds.maxY) / 2
        let h = hash(seed, center, centerY, islandID.raw)
        return nameTable[Int(h % UInt64(nameTable.count))]
    }
}

private let nameTable: [String] = [
    "Greenwood", "Stoneholm", "Tinmouth", "Fairhaven", "Old Salt",
    "North Reach", "Bay of Knives", "Whaleback", "Linden", "Marrow",
    // … 64 total, hand-curated for variety + readability
]
```

Names are deterministic per (seed, island geometry). The same seed + same archipelago layout → same names. World-gen sets the name once and persists it; loaded saves keep their original names even if the table changes in a future release.

**Alternatives considered:**

- *Procedural name generator (markov chain on a corpus).* Rejected — overkill for 64 fixed names. The constant table is auditable, localizable, and cheap.
- *"Island 1", "Island 2".* Rejected — robs the world of texture for no implementation savings. The user explicitly asked for generated names.
- *Player-renameable.* Out of scope; the UI surface is non-trivial and the deterministic-pick name is good enough at launch. Add as a follow-up if requested.

### D4. Sticky behavior over water

`HUDViewModel.currentIsland` is updated each snapshot by:

```swift
if let id = snapshot.island(at: snapshot.camera.centerTile()) {
    currentIsland = snapshot.islandSummaries[id]
} else {
    // over water — keep previous
}
```

When the camera first opens (no previous island) and is over water, `currentIsland` is nil and the HUD island row simply hides. As soon as the camera enters any island, the row appears and stays populated. Pressing inside another island swaps. Crossing water between two islands keeps the source island until the camera enters the destination.

**Alternatives considered:**

- *Show all-island aggregate over water.* Rejected — confusing; the player just lost their reference frame and gets a new set of numbers.
- *Hide the panel entirely over water.* Rejected — the player loses information at the moment they want it most (e.g. "do I have enough wood to ship somewhere new?").
- *Show closest island by Euclidean distance.* Rejected — surprises the player when the closeness flips mid-sail.

### D5. Good icons procedurally generated, bundled in their own atlas

`scripts/generate-sprites.swift` gains a `drawGoodIcon(good:)` function emitting 24×24 PNGs with:

- A simple recognizable silhouette: wood = a horizontal log with darker stripe ends; planks = stacked planks with grain; food = a round loaf with a crust.
- A 1-pixel dark outline so the icon reads against the HUD's translucent background.
- Same nearest-neighbor crispness as the rest of the sprite pipeline.

Icons live in `Resources/Icons.atlas/`, a new fourth category alongside Terrain/Buildings/Units. The sprite-name grammar gains the `good-` prefix routing here. SwiftUI loads them as `UIImage`/`NSImage` (the SwiftUI-friendly path) rather than going through the SpriteKit `SKTexture` route — the HUD is SwiftUI and there's no value pulling SpriteKit textures into a `View`.

**Alternatives considered:**

- *Hand-drawn icons commissioned externally.* Rejected — adds an external dependency and asset-pipeline complication. Procedural fits the project's existing aesthetic.
- *SF Symbols.* Tempting and free, but they don't match the pixel-art look of the rest of the game. The HUD already uses `.thinMaterial` chrome that bridges modern and pixel-art fine, but the goods icons sit *with* numerical readouts that read as game data — pixel art reinforces that.
- *Bundle icons in the existing Buildings.atlas or Units.atlas.* Rejected — both atlases are SpriteKit-routed and the HUD doesn't go through SpriteKit. Cleaner to have a dedicated Icons atlas that SwiftUI reads directly.

### D6. SwiftUI bridge to atlas-bundled pixel art

```swift
// Lives in CityUI (the HUD's owner).
enum GoodIconLoader {
    @MainActor
    static func image(for good: Good) -> Image? {
        guard let url = Bundle.main.url(
            forResource: "good-\(good.rawValue)",
            withExtension: "png"
        ) else { return nil }
        #if canImport(UIKit)
        guard let ui = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: ui).interpolation(.none)
        #elseif canImport(AppKit)
        guard let ns = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: ns).interpolation(.none)
        #else
        return nil
        #endif
    }
}
```

`.interpolation(.none)` keeps the pixel-art crisp at every zoom level. Fallback path: missing icon → SF Symbol `cube.fill` so the row never goes blank.

### D7. Capacity tracking — show in the panel?

Each warehouse + port has a per-good capacity. Two display options for the HUD chip:

- **Just the count**: `▣ Wood 12`
- **Count + capacity**: `▣ Wood 12 / 200`

The second adds visual noise but tells the player "you have 6% of your storage filled" — useful for triggering "I need more warehouses." The first is cleaner.

Pick: **Count only in the chip, capacity in the tap-to-inspect tooltip** (Inspector already renders per-building, which shows the per-warehouse fraction). The HUD stays uncluttered.

### D8. Determinism

`Island.name` is set deterministically at world-gen (seeded pick from a constant table). The name is part of `Island`, which is part of `World`, which is `Codable`. Save/load round-trips identically. Two `single-island` worlds with the same seed get the same island name; two `archipelago` worlds with the same seed get the same set of names assigned in the same order.

`islandSummaries` in the snapshot is recomputed every snapshot and never affects `World` mutation order. Replay determinism is preserved.

## Risks / Trade-offs

- **[Gated on archipelago landing its Island metadata]** → Mitigation: ship the snapshot-shape and HUD work behind a feature flag, or wait for archipelago's M-task that introduces `Island` records to merge. The current archipelago progress (25/64) suggests Island is among the earlier tasks; coordinate with that agent before starting.
- **[Procedural icon legibility at 24×24 may be poor]** → Mitigation: drawGoodIcon is a tunable function; iterate. If 24×24 doesn't read, bump to 32×32 (HUD has the room) without changing the architecture.
- **[Name table feels generic]** → Mitigation: 64 names hand-curated for medieval/coastal flavor. Easy to revise in a follow-up; saves preserve old names so the user's existing world isn't disrupted.
- **[Sticky behavior surprises on long sea crossings]** → Mitigation: documentation hint or a small "(last on: Greenwood)" subscript. Default is just to show the island as if you're still on it; that matches the player's mental model.
- **[Capacity not shown — player misses warehouse-full signals]** → Mitigation: stalled-production audio in Phase 2 of audio. Visible per-warehouse capacity in the Inspector. The HUD's role is glanceable, not exhaustive.

## Migration Plan

No save-format change. `Island.name` is added to a type that already exists in v2 saves (archipelago bumps to v2); the field defaults to the deterministic name when missing in older v2 saves.

If a v2 save was written before this change lands, the load path recomputes the name from the deterministic picker — same name as if the world had been generated post-change. No user-visible disruption.

Rollback is a clean revert with no data implications.

## Open Questions

- **Capacity bar instead of fraction?** A 4-segment bar `▣▣▢▢` is visually denser than `12 / 200`. Could land as a polish iteration after the basic chip ships.
- **Show goods with zero stock and zero capacity?** Probably hide — chips that always read 0 are noise. Show the chip when (a) any warehouse on the island has any capacity for that good, or (b) the island currently holds at least 1 of that good. Single-island starter players see only wood early on, then planks, then food.
- **What about goods produced by future buildings (cloth, fish, ale)?** The chip layout needs to scale. With 8 goods the row gets long. Either wrap to two rows or scroll horizontally; decide when there are >5 goods to display.
