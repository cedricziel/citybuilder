## Why

The coast and the sawmill are among the stillest parts of the town. A fish jumping near the shore and sawdust puffing at a working mill are the two cheapest ideas on the liveliness canvas, options A of "Fish" and "Sawdust", ranked third and fourth (issue #188). Part of #127.

## What Changes

- **Fish:** every 8–15 s by day, one fish jumps from a visible open-water tile (water all round, so never a shore tile) within 4 tiles of land. It makes a short arc and leaves a splash ring where it dives back in. A jump is one group with a 3-frame fish and a ring, all drawn in code, so at most 3 nodes are on screen. The fish are nodes of their own above the water, so they work whether open water is drawn as tiles or as one backdrop (#202).
- **Sawdust:** each working player sawmill on screen (operational, no building issue) has one emitter of small, pale puffs at the middle of its front edge. Up to 8 mills are shown, by id. Emitters are pooled.
- Both follow the shared liveliness rules. They hold still at night and while the game is paused, are off with Reduce Motion and below zoom 0.5, and are deterministic: fish draw from a seeded generator on scene time, and sawdust reads the snapshot. Both sort by the depth of their position.

## Capabilities

### Modified Capabilities
- `rendering-2_5d`: adds "Fish jump near the coast" and "Sawdust puffs at the sawmills".

## Impact

- **CityRender2D:** new `FishJumps.swift` and `Sawdust.swift`, each a layer node the scene reconciles once per frame. The smoke puff texture is reused.
- **CityCore:** no change.
