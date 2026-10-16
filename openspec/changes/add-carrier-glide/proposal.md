## Why

Carriers are the town's most visible traffic, yet they jump from tile to tile at 10 Hz. They also look exactly like strolling residents, so a road full of deliveries reads as people idling. Part of #127.

## What Changes

- A carrier glides to each new tile over the time since its last step. It keeps pace at every game speed instead of snapping.
- A carrier's sprite comes from its load's good family (logs, sack, barrel or crate) through one lookup, `SpriteAtlas.carrierAnimation(load:facing:)`. The lookup reads `carrier-<family>-<facing>-<frame>` and falls back to the walker frames. The walkers agent is modelling those carrier sprites in IsoKit. Until they land, carriers look as they do today, so no art is drawn in code here.

## Capabilities

### Modified Capabilities
- `rendering-2_5d`: adds "Carriers glide and show their load".

## Impact

- **CityRender2D:** carrier rendering moves out of `IsoWorldScene.swift` into `CarrierRendering.swift`. It adds `CarrierLoad` and `SpriteAtlas.carrierAnimation`, and routes `carrier-` sprites to the Units atlas.
- **CityCore:** no change.
