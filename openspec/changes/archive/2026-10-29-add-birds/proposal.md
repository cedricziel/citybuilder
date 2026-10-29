## Why

The sky over the town is empty. Birds crossing now and then, and gulls over the coast, are cheap cues of a living landscape. This change takes options A and B together from the liveliness design canvas. Part of #127.

## What Changes

- By day, a loose flock of 5–9 dark birds crosses the view every 40–90 s. Each bird flaps on a two-stroke silhouette drawn in code, and casts a faint shadow. Only one flock flies at a time.
- By day, when coast is on screen and the zoom is at least 0.5, three gulls wheel slowly over one coastal water tile. The gulls are white with dark wing tips.
- No birds at night, and none with Reduce Motion on.
- Birds run on scene time, not the simulation tick, so they never touch simulation state. Their timing comes from a seeded generator.

## Capabilities

### Modified Capabilities
- `rendering-2_5d`: adds "Birds cross the sky".

## Impact

- **CityRender2D:** the new `Birds.swift` adds a bird layer at z 90, over the buildings and under the night shade, plus the coast pick, the flock shape and the silhouettes drawn in code.
- **CityCore:** no change.
