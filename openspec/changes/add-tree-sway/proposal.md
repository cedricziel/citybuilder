## Why

Forest covers half of every island, and every clump stands perfectly still. A slight sway in the wind makes the most screen look alive for the least cost. This is option A of "Tree sway" on the liveliness design canvas, approved. Part of #127.

## What Changes

- Each tree clump rocks about its trunk base, ±0.7° at most, over about 3.5 s. Its phase comes from a hash of its tile, so neighbouring clumps never sway in step. Rock outcrops stay still.
- The sway is one shared SpriteKit action. A clump gets it when its node is made, so it survives the incremental add and remove from reconcile-on-change, and no frame does Swift work per clump.
- Below zoom 0.5 and with Reduce Motion on, clumps stop and stand upright. While the game is paused they hold mid-sway. The scene touches the clumps on screen only when one of those states changes.

## Capabilities

### Modified Capabilities
- `rendering-2_5d`: adds "Trees sway in the wind".

## Impact

- **CityRender2D:**
  - `makeObjectNode` arms the sway on forest objects.
  - The new `TreeSway.swift` holds the shared action and the scene's state switch.
- **CityCore:** no change.
