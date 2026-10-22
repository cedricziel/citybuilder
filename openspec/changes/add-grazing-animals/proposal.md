## Why

Farms sit in empty meadows and houses stand without a yard. Animals near the farms and hens at the doors are the most direct way to make the countryside look worked and lived in. These are options A and Hens on row 5 of the liveliness canvas, using the animal sprites from #164. Part of #127.

## What Changes

- Each operational farm keeps 2–4 sheep, and each grain farm 1–2 cows. They stand on free grass within 2 tiles of the farm: grass with no building, road or field on it and no tree or rock from the terrain object map. They mostly graze, and every 6–10 s one walks a short way to another free spot. At night they stand still. A farm with no free grass nearby has no animals.
- Each inhabited peasant house keeps 1–2 hens on the front edge of its plot. Every few seconds a hen hops to a new spot. The hens are inside at night.
- Animals are drawn from the snapshot alone and never touch the simulation. Positions are a pure function of the building, slot and tick.
- Budget:
  - At most 30 herd animals and 24 hens on screen.
  - No herd animals below zoom 0.5, and no hens below zoom 0.75.
  - With Reduce Motion on, animals stand still.
  - While the game is paused, animals stop moving.

## Capabilities

### Modified Capabilities
- `rendering-2_5d`: adds "Animals graze by the farms" and "Hens peck by the houses".

## Impact

- **CityRender2D:**
  - The new `AnimalPlanner` and `AnimalLayer` draw through `SpriteAtlas.animalAnimation(_:facing:)` and `action.anchor`.
  - The free-grass test reads the scene's `TerrainObjectMap` and the snapshot's occupancy.
- **CityCore:** no change.
