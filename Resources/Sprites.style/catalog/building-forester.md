---
source = "isokit"
---
## Function

Forest-planting building. The forester turns open grass within 2 tiles
of its footprint into forest, one tile per cycle, so the lumberjack hut
beside it never runs out of trees. It needs no road and stores no
goods. The operational animation shows a working building from a
distance.

## Visual identity

Rendered by IsoKit in the shared light rig. A small half-timbered hut under a thatch roof in the back corner, its yard a nursery of young conifers in rows behind a fence.

## Sprites

- `building-forester` — canonical operational base
- `building-forester-constructing-0` — foundation (stone pad)
- `building-forester-constructing-1` — frame raised (timber
  posts, no roof)
- `building-forester-constructing-2` — walls up under
  scaffolding, no saplings yet
- `building-forester-operational-0` — finished shed and
  nursery
- `building-forester-operational-1` — same, with a smoke wisp

## Recipe

- Recipe: `building-forester` (IsoKit)
- Cell: 2×2 footprint, 112 pt tall
- Construction stages: 3
- Operational frames: 2
