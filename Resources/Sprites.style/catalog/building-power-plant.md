---
source = "isokit"
---
## Function

Modern age signature. Burns charcoal; while fuelled it energises houses and speeds up workshops within 10 tiles. It only animates while fuelled.

## Visual identity

Rendered by IsoKit in the shared light rig. A brick hall on a concrete base with tall windows and a concrete cornice under a slate roof, two concrete chimneys with red bands, and a fenced transformer yard.

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

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-power-plant` (IsoKit)
- Cell: 3×3 footprint, 224 pt tall
- Construction stages: 3
- Operational frames: 2
