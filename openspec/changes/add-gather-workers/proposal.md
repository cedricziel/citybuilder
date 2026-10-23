## Why

Lumberjack huts and mines sit next to their forest or rock with nobody at work. A worker walking out to the trees and coming back with logs shows the economy at work, and an idle site that stays empty tells the player something is wrong. This is option B of "Workers at gather sites" on the liveliness design canvas, approved. Part of #127.

## What Changes

- Each working player lumberjack hut and mine (operational, no building issue) has one worker. The worker walks out tile by tile, over free grass, road and the site's own forest or rock, to a tree or rock face in the hut's catchment, and works there a while. Then they walk back with the existing carrier frames for logs or a crate, and rest at the hut.
- A site that is idle or has no reachable tree or rock shows no worker.
- Workers move by the animals' day clock. They stand still at night, while the game is paused, and with Reduce Motion on. They sort by their feet (`figureZ(at:)`) and use the herds' zoom gate (none below 0.5). At most 16 are drawn.
- Drawn from the snapshot only; the simulation is untouched.

## Capabilities

### Modified Capabilities
- `rendering-2_5d`: adds "Workers walk out from the gather sites".

## Impact

- **CityRender2D:** the new `GatherWorkers.swift` holds the planner and its scene layer, reusing `AnimalPlanner.dayClock`, the walker and carrier frames, and `figureZ(at:)`.
- **CityCore:** no change. It reads `World.lumberjackCatchmentRadius`.
