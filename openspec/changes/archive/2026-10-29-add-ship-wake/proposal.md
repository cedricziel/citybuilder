## Why

Ships glide over the water without disturbing it, which makes them read as pasted on. A wake is the clearest cue that a ship is under way. This is option A, the foam V, on the liveliness design canvas. Part of #127.

## What Changes

- A ship that is moving leaves foam behind its stern. The foam stays where it was laid on the water, spreads into a V and fades in about 2 s.
- The foam stops 0.3 s after the ship stops moving, so docked ships and a paused game lay none.
- Below zoom 0.5 the trail is shorter. With Reduce Motion on, the trail has half the puffs, spread at half the speed.
- One pooled emitter per visible ship, reusing the smoke's code-drawn puff texture. The foam is drawn in a wake layer over the water and under buildings and ships.

## Capabilities

### Modified Capabilities
- `rendering-2_5d`: adds "Ships leave a wake".

## Impact

- **CityRender2D:**
  - `ShipLayerNode` gives each ship node a wake emitter that targets `IsoWorldScene.wakeLayer`.
  - The new `ShipWake.swift` holds the emitter's look and the stern maths.
- **CityCore:** no change.
