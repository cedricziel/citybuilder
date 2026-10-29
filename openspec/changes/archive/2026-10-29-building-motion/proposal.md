## Why

Building animations (the windmill's sails, the sawmill's saw, the port's crane, the shipyard's hull) ignore Reduce Motion and keep running while the game is paused. The rest of the map's life respects both: figures stand still when paused, trees hold their sway, birds stay away under Reduce Motion. Building animation should follow the same rule.

## What Changes

- **Reduce Motion:** each animated building rests on its operational frame 0, culture looks included.
- **Pause:** when the game is paused, which here means no tick for 0.3 s, as for figures, building animations hold their current frame. They run again on the next tick.
- **One scene-level state:** running, held or stopped. It changes only when the state flips, the same pattern as `TreeSway`, and costs nothing per frame. Only each building's animation slows; badges, glows and pennants on the building keep their own motion.
- **One frame resolver (refactor, no behaviour change):**
  - `SpriteAnimation.AnimationKey.buildingOperational` carries the look's stem, a culture variant or a shore facing.
  - `SpriteAnimation.assetName` and `loopingAction` then serve every building's frames.
  - The second, string-built path (`operationalAction` and its cache) is removed.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: adds "Building animations follow pause and Reduce Motion".

## Impact

- **CityRender2D:**
  - New: `BuildingMotion.swift`.
  - Changed: `IsoWorldScene.swift` (state and update call), `SceneNodeFactories.swift` (one `armAnimation`), `SpriteAnimation.swift` (stem on the key), `CultureSprites.swift` (`operationalAction` removed).
- **Determinism:** none; the simulation is unchanged.
