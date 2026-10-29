## Why

An animal's round runs through the free tiles around its farm or house, and it was worked out afresh every tick. A road or building placed on one of those tiles changed the round, so a sheep could jump to the far side of the pasture. Gather workers already keep their trip from tick to tick for the same reason (#198). Separately, the scene dropped its animals and workers for a new world only when the tick ran backwards or the map changed shape, so a different game of the same size at a later tick kept the old game's figures. Part of #181.

## What Changes

- The scene keeps each animal's round. A round stays while all its tiles are open. When a tile on it is built on, the animal plans a new round from where it stands: it walks from its current spot to the tile it was heading for, or to the nearest open tile when that one is gone, and goes on from there. Building on the pasture never makes an animal jump.
- Each game gets its own map view: the title screen host gives the game view the session's identity, so starting or loading another game builds a fresh scene. The tick-and-map-shape check that dropped the figures goes away.
- Drawn from the snapshot only; the simulation is untouched.

## Capabilities

### Modified Capabilities
- `rendering-2_5d`: adds "Animals keep their round when the pasture changes". The gather workers' rule for a different world now follows from the fresh scene per game.

## Impact

- **CityRender2D:** `AnimalPlanner` takes and returns each animal's round (`Tour`); `IsoWorldScene` keeps them. `dropFiguresIfNewWorld` and `MapShape` go.
- **CityUI:** `TitleScreenHost` keys the game view on the session.
- **CityCore:** no change.
