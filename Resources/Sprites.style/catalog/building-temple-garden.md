---
source = "isokit"
---
## Function

East Asian culture signature. Houses of citizens and above within 6 tiles of an operational temple garden add 1 extra knowledge per resident every 100 ticks, or 2 while it is served tea.

## Visual identity

Rendered by IsoKit in the shared light rig. Grey raked gravel round a small shrine on a stone plinth under a hipped slate roof, a red torii gate, a stone lantern, a pond and a pine.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-temple-garden` — canonical idle base (unserved)
- (0, 1): `building-temple-garden-constructing-0` — stone pad
- (0, 2): `building-temple-garden-constructing-1` — timber frame
- (0, 3): `building-temple-garden-constructing-2` — walls with scaffolding
- (1, 0): `building-temple-garden-operational-0` — operational frame 0
- (1, 1): `building-temple-garden-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Played only while served.

## Recipe

- Recipe: `building-temple-garden` (IsoKit)
- Cell: 3×3 footprint, 160 pt tall
- Construction stages: 3
- Operational frames: 2
