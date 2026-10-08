---
source = "procedural"
---
## Function

Renaissance age signature. A paid commission inspires houses within 8 tiles to grow faster for 1,200 ticks; the banner only flies while a commission runs.

## Visual identity

An ochre stuccoed palazzo front over a stone arcade of three arches, a cornice, a statue niche between the upper windows and a red banner on a pole on the roof. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-gallery` — canonical idle base
- (0, 1): `building-gallery-constructing-0` — stone pad
- (0, 2): `building-gallery-constructing-1` — timber frame
- (0, 3): `building-gallery-constructing-2` — walls with scaffolding
- (1, 0): `building-gallery-operational-0` — banner flutter, first wave
- (1, 1): `building-gallery-operational-1` — banner flutter, second wave
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
