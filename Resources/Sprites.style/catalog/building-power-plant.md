---
source = "procedural"
---
## Function

Modern age signature. Burns charcoal; while fuelled it energises houses and speeds up workshops within 10 tiles. It only animates while fuelled.

## Visual identity

A brick hall on a concrete base with tall windows and a concrete cornice under a slate roof, two concrete chimneys with red bands, and a transformer yard with a lattice pylon. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-power-plant` — canonical idle base
- (0, 1): `building-power-plant-constructing-0` — stone pad
- (0, 2): `building-power-plant-constructing-1` — timber frame and chimney stubs
- (0, 3): `building-power-plant-constructing-2` — brick walls with scaffolding
- (1, 0): `building-power-plant-operational-0` — windows glowing, chimney haze
- (1, 1): `building-power-plant-operational-1` — windows glowing in the other pattern, haze rising
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
