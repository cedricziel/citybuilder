## Why

The HUD shows two numbers: money and population. Every other piece of game state — what goods are stocked, where, and how full each warehouse is — is invisible to the player. The simulation tracks all of it; the shell exposes none of it.

Multi-island worlds (landing via `add-archipelago-and-sea`) make this gap bigger, not smaller. Carriers can't cross water, so an island's stockpile is the only stockpile that matters when the player wants to know "can I build something here?". Aggregating goods across all islands would actively mislead.

This change adds a stocks panel under the existing money/population badge, scoped to the island under the camera. It also names islands so the player has a referent when they look at the panel ("Greenwood: 12 wood, 4 planks"). Procedurally generated good icons sit alongside counts so the row reads at a glance.

The change is **display only** — no gameplay rule changes. Buildings remain money-only. That's `add-build-materials-cost`'s job (follow-up).

## What Changes

- `WorldSnapshot` gains `islandSummaries: [IslandID: IslandSummary]` where `IslandSummary` carries `(name: String, bounds: TileRect, stockpile: [Good: Int], capacity: [Good: Int])`. Aggregates are summed across every warehouse, port, and shipyard on the island. (`warehouses-and-logistics` modified.)
- `WorldSnapshot` gains `island(at:) -> IslandID?` — a tile→island lookup used by the HUD to derive the current island from the camera center. Returns nil for water tiles outside any island's bounding box. (`world-terrain` modified.)
- `Island` (the existing record from `add-archipelago-and-sea`) gains a deterministic `name: String` derived at world-gen from a seeded pick over a 64-entry name table indexed by island center coordinate. Saves preserve the name through the existing Codable conformance. (`world-terrain` modified.)
- `HUDViewModel` gains a `currentIsland: IslandSummary?` derived from the snapshot's camera center via `island(at:)`. Sticky over water: when the camera is over water, the HUD continues to display the last island it was over until the camera enters a different island.
- HUD layout extends with: an island-name badge to the right of the existing money/population badge, and a row of `(good icon, count)` chips below for each good present in the island's stockpile (or with non-zero capacity for any warehouse on the island).
- Procedurally generate good icons via `scripts/generate-sprites.swift`: `good-wood.png`, `good-planks.png`, `good-food.png`, 24×24, nearest-neighbor pixel art. Bundle in a new `Resources/Icons.atlas/`. (`sprite-asset-pipeline` modified.)
- Sprite-name grammar extends with the `good-` prefix routing to a new `Icons` atlas. (`sprite-asset-pipeline` modified.)
- HUD rendering reads icons via the existing `SpriteAtlas` infrastructure but renders them as `Image` in SwiftUI rather than `SKSpriteNode` in SpriteKit — a small bridge that loads the PNG as a `UIImage`/`NSImage` and forwards to SwiftUI.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `rendering-2_5d`: HUD layout adds an island badge + stocks row driven by `HUDViewModel.currentIsland`. Camera-center-to-island lookup pulled from snapshot, not from `World`.
- `warehouses-and-logistics`: snapshot exposes per-island aggregate stockpile + capacity. Storage queries operate against any goods-buffer (warehouse OR port).
- `world-terrain`: `Island` gains a deterministic generated `name`. Name table is seeded; same world seed → same names.
- `sprite-asset-pipeline`: extends the naming grammar with a `good-` prefix routing to a new `Icons.atlas`. Sprite-generation script gains a `drawGoodIcon` helper.

## Impact

- **CityCore** — `WorldSnapshot` gains two fields (`islandSummaries`, internal `tileToIsland` map) and one method (`island(at:)`). `Island` (already landing via archipelago) gains `name: String`. World-gen runs the name picker once, persists with the world.
- **CityUI** — `HUDViewModel` gains `currentIsland: IslandSummary?` and `previousIsland: IslandSummary?` for the sticky-over-water behavior. `HUDFrameView` gains an island row.
- **CityRender2D** — no scene changes. Good icons are bundle resources the HUD reads as SwiftUI `Image`. The `Icons.atlas/` is registered alongside the existing three atlases.
- **CityAudio** — no changes.
- **CityPersistence** — `Island.name` is `Codable` (just a String); save format is backward-compatible because the name is added by world-gen, and v1 saves regenerate names on load via the same deterministic picker. No schema bump.
- **scripts/generate-sprites.swift** — gains `drawGoodIcon(good:)` helpers and emits three 24×24 PNGs to `Resources/Icons.atlas/`.
- **project.yml** — Resources/Icons.atlas added to both app targets' resource paths.
- **No CityCore behavioral changes.** Money, population, carriers, production, economy — all unchanged. Pure additive snapshot.
- **No new build-time tool dependency.**
- **Performance** — per-island aggregate is O(buildings on island) per snapshot. With ≤100 buildings on a maxed island, well inside the existing 5 ms per-tick budget. Aggregates are computed at snapshot time, not stored on `World`.
- **Gates on**: `add-archipelago-and-sea` landing its Island metadata. Without `Island` records and `IslandID`, this change has nothing to scope against.
