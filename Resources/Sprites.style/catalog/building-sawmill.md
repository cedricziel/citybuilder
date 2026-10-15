---
source = "isokit"
---
## Function

Wood-to-planks producer. A sawmill consumes wood from adjacent storage
and emits planks. The 4-frame operational animation shows a vertical
sawblade rising and falling — the most visible "industry is running"
signal in the world.

## Visual identity

Rendered by IsoKit in the shared light rig. A plank mill under a thatch roof with a dark saw opening in its south wall and four sails on the east gable, logs and sawn planks stacked in a sawdust yard.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size. All 8 cells used.

- (0, 0): `building-sawmill` — canonical operational base (saw at rest,
  centred)
- (0, 1): `building-sawmill-constructing-0` — foundation (stone
  plinth, corner posts)
- (0, 2): `building-sawmill-constructing-1` — frame raised (full
  timber skeleton, no walls)
- (0, 3): `building-sawmill-constructing-2` — walled + roofing (wall
  planks installed, half-tiled roof)
- (1, 0): `building-sawmill-operational-0` — saw blade up (top of
  stroke)
- (1, 1): `building-sawmill-operational-1` — saw blade upper-mid
- (1, 2): `building-sawmill-operational-2` — saw blade lower-mid
- (1, 3): `building-sawmill-operational-3` — saw blade down (cut
  contact; small sawdust puff)

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the sails turn through 4 overlay frames.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)` → `(1, 2)` → `(1, 3)`. All four
  frames are placed in adjacent cells on row 1.

## Recipe

- Recipe: `building-sawmill` (IsoKit)
- Cell: 2×2 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 4
- Moving part: sails, 4 frames, sweeps right
