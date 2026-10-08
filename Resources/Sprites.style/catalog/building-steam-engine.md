---
source = "procedural"
---
## Function

Industrial age signature. Burns charcoal; while fuelled it doubles the speed of workshops within 6 tiles and smokes houses within 4 tiles. It only animates while fuelled.

## Visual identity

A brick engine house under a slate gable roof, a tall round brick chimney, a rocking beam on a stone bob wall over a pump head, and a coal heap. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-steam-engine` — canonical idle base
- (0, 1): `building-steam-engine-constructing-0` — stone pad
- (0, 2): `building-steam-engine-constructing-1` — timber frame and a half-built chimney
- (0, 3): `building-steam-engine-constructing-2` — brick walls with scaffolding
- (1, 0): `building-steam-engine-operational-0` — beam up with a smoke puff
- (1, 1): `building-steam-engine-operational-1` — beam down
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
