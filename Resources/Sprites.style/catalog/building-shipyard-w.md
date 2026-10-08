---
operational = "derived"
---
## Function

Shore-placement ship producer. Consumes wood + planks; emits Ships.
This catalog entry is the **west-facing** shipyard — sea side is
east.

## Visual identity

Stone slipway sloping east into the water; boat-shed on the inland
(west) side. Palette, silhouette register, and outline weight MUST
match `building-shipyard-n.md`. 2-frame hull-work animation.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-shipyard-w` — canonical operational base
- (0, 1): `building-shipyard-w-constructing-0` — slipway formwork
- (0, 2): `building-shipyard-w-constructing-1` — slipway + shed posts
- (0, 3): `building-shipyard-w-constructing-2` — shed framed
- (1, 0): `building-shipyard-w-operational-0` — hull partly planked
- (1, 1): `building-shipyard-w-operational-1` — hull more planked
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Hull work: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Operational frames are derived locally from the base sprite (front matter
`operational = "derived"`): the building stays pixel-identical and a chimney
smoke plume rises over the roof, so the loop never swaps one drawing for
another. The per-frame roles above describe the original AI frames.
