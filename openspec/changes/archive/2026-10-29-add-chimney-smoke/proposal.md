## Why

The owner played the game and found "too little liveliness". A town of inhabited houses and working bakeries sits still. Only carriers, ships, strollers and a few two-frame building loops move. Smoke from chimneys is the cheapest cue that a building is lived in or at work, and it reads at every zoom level.

## What Changes

- Inhabited houses and working fire trades show smoke rising from their chimney. The fire trades are the bakery, smelter, toolsmith and charcoal burner.
- A working brewery shows white steam instead of smoke.
- A workshop with an issue shows no smoke, for example one with missing inputs or full storage. An empty house shows none either.
- Smoke is drawn by a capped pool of SpriteKit emitters on one ambient layer. The cap shrinks as the camera zooms out, and working buildings win over houses. The puff texture is drawn in code.
- When Reduce Motion is on, smoke rises at half the rate and half the speed.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: adds the requirements "Chimneys smoke" and "Ambient effects stay in budget".

## Impact

- **CityRender2D:**
  - `ChimneyPlanner` decides which buildings smoke, from the snapshot alone.
  - `AmbientLayerNode` pools the emitters.
  - `ChimneyAnchors` holds where each sprite's chimney sits.
  - `IsoWorldScene.reduceMotion` is set by `IsoWorldView` from the environment.
- **CityCore:** no change. Smoke is cosmetic and reads only the snapshot, so determinism and the fixture are untouched.
