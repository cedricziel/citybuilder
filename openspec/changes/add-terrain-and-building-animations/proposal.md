## Why

Only the walker has animation today (2-frame walk cycle, 4 facings). All 5 terrain tiles and all 6 buildings are static PNGs, which makes the island feel inert — water doesn't move, sawmill smoke doesn't rise, a building under construction is signalled with `alpha = 0.55` and nothing else. We have the rendering hooks (`SpriteAtlas.walkerAnimation` already returns multi-frame `[SKTexture]`), but no atlas entries or driver logic for non-walker sprites. Adding a small set of looped idle animations and a construction-progress animation closes the largest visible gap between the current renderer and the Caesar III / Anno 1602 reference look the project is targeting.

## What Changes

- Introduce a generalized animation lookup in `SpriteAtlas` (CityRender2D) that returns `[SKTexture]` + frame duration for any sprite, not just walkers. Existing `walkerAnimation` becomes one consumer.
- Add procedurally generated frame sets to `scripts/generate-sprites.swift` and ship the resulting PNGs under `Resources/Sprites/`:
  - `terrain-water-{0..3}.png` (4-frame shimmer)
  - `terrain-beach-{0..1}.png` (2-frame surf)
  - `building-sawmill-operational-{0..3}.png` (4-frame saw + chimney smoke)
  - `building-lumberjack_hut-operational-{0..1}.png` (2-frame chimney smoke)
  - `building-townCenter-operational-{0..1}.png` (2-frame banner flutter)
  - `building-*-constructing-{0..2}.png` (3-frame scaffold rise) for every building kind
- `IsoWorldScene` plays terrain idle animations on the terrain layer and per-building state-driven animations on operational and constructing buildings. Construction frame advances with build progress (deterministic, derived from `WorldSnapshot.tickCount` and the building's start tick) so two clients of the same save render the same scaffold stage.
- Off-screen culling stops animations: nodes that leave the visible range have their `SKAction` keys removed when removed from the scene (already happens via reconciler) and re-armed on re-add.
- Animation timings live in a single `SpriteAnimation` catalog so designers can tune cadence without touching scene code.
- No simulation changes. CityCore stays untouched.

## Capabilities

### New Capabilities
- `sprite-animation`: Looped idle animations for terrain, state-driven animations for buildings (operational vs constructing), construction-progress frame selection, and the multi-frame atlas API that backs them.

### Modified Capabilities
<!-- None. The `rendering-2_5d` capability is still being defined inside the in-flight add-mvp-foundation change, so its archived spec doesn't exist yet. -->

## Impact

- **CityRender2D** — new `SpriteAnimation` catalog, expanded `SpriteAtlas` API (multi-frame lookup, animation key resolver from `BuildingState`/`TerrainType`), changes to `IsoWorldScene.makeTerrainNode` / `makeBuildingNode` to arm `SKAction.animate(...)` and to update the action key when a building transitions `constructing → operational`. New unit tests for catalog lookup and deterministic construction-frame derivation.
- **Resources/Sprites/** — ~25 new PNGs. `scripts/generate-sprites.swift` extended with frame-generation helpers (smoke puffs, shimmer offset, scaffold layering). Asset bundle grows; well under any meaningful size budget.
- **No simulation, persistence, or CityCore changes.** No save-format change. No new build-time tool dependency.
- **Performance** — Idle terrain animations are the highest-volume new actions. Mitigation: share one `SKAction` instance across all tiles of the same terrain type (SpriteKit allows shared action references on independent nodes), keep frame counts small (2–4), and rely on the existing visible-tile culling so off-screen tiles never animate.
