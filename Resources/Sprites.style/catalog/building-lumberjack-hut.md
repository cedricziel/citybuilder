---
source = "isokit"
---
## Function

Forest-extraction building. A lumberjack walker spawns from this hut
and harvests wood from adjacent forest tiles. The operational
animation shows an axe-swing rhythm to communicate "actively working"
from a distance.

## Visual identity

Rendered by IsoKit in the shared light rig. A plank hut under a steep thatch roof with a chimney, split logs stacked against its east wall and in the yard, stumps with an axe in one, and a fence on the east edge.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-lumberjack-hut` — canonical operational base
- (0, 1): `building-lumberjack-hut-constructing-0` — foundation (stone
  pad + corner posts)
- (0, 2): `building-lumberjack-hut-constructing-1` — frame raised
  (timber skeleton, no roof)
- (0, 3): `building-lumberjack-hut-constructing-2` — thatching
  (half-thatched roof + scaffolding)
- (1, 0): `building-lumberjack-hut-operational-0` — axe up (lumberjack
  silhouette mid-swing, no smoke)
- (1, 1): `building-lumberjack-hut-operational-1` — axe down (chopping
  block flares; small smoke wisp from chimney)
- (1, 2): spare
- (1, 3): spare

## Animation

Two animation loops: construction (one-shot) and operational (forever).

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`,
`units.py`) in the register pinned by `world.md` § Building register.
Operational frames keep the finished building and add a rising smoke plume.
The per-cell roles above describe the original AI sprites.

## Recipe

- Recipe: `building-lumberjack-hut` (IsoKit)
- Cell: 2×2 footprint, 112 pt tall
- Construction stages: 3
- Operational frames: 2
