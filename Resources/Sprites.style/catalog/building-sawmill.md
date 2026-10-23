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

## Sprites

- `building-sawmill` — canonical operational base (saw at rest,
  centred)
- `building-sawmill-constructing-0` — foundation (stone
  plinth, corner posts)
- `building-sawmill-constructing-1` — frame raised (full
  timber skeleton, no walls)
- `building-sawmill-constructing-2` — walled + roofing (wall
  planks installed, half-tiled roof)
- `building-sawmill-operational-0` — saw blade up (top of
  stroke)
- `building-sawmill-operational-1` — saw blade upper-mid
- `building-sawmill-operational-2` — saw blade lower-mid
- `building-sawmill-operational-3` — saw blade down (cut
  contact; small sawdust puff)

## Recipe

- Recipe: `building-sawmill` (IsoKit)
- Cell: 2×2 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 4
- Moving part: sails, 4 frames, sweeps right
