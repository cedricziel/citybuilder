---
source = "procedural"
---
## Function

Shore-placement ship producer. Consumes wood + planks; emits Ships.
This catalog entry is the **south-facing** shipyard — sea side is
north.

## Visual identity

Stone slipway sloping north into the water; boat-shed on the inland
(south) side with the open frontage facing the camera. Palette,
silhouette register, and outline weight MUST match
`building-shipyard-n.md` so the four orientations read as the same
building. 2-frame hull-work animation.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-shipyard-s` — canonical operational base
- (0, 1): `building-shipyard-s-constructing-0` — slipway formwork
- (0, 2): `building-shipyard-s-constructing-1` — slipway + shed posts
- (0, 3): `building-shipyard-s-constructing-2` — shed framed
- (1, 0): `building-shipyard-s-operational-0` — hull partly planked
- (1, 1): `building-shipyard-s-operational-1` — hull more planked
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Hull work: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`,
`units.py`) in the register pinned by `world.md` § Building register.
Operational frames keep the finished building and add a rising smoke plume.
The per-cell roles above describe the original AI sprites.
