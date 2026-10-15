---
source = "isokit"
---
## Function

Middle Eastern culture signature. Every 100 ticks a caravan sells up to 4 goods (8 while served coffee) at base price, the chosen export good first.

## Visual identity

Rendered by IsoKit in the shared light rig. A sandstone courtyard: tall arcaded wings on the two back sides, a blue-tiled corner dome, a gate in the low front wall, a palm and a crate.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-caravanserai` — canonical idle base (unserved)
- (0, 1): `building-caravanserai-constructing-0` — stone pad
- (0, 2): `building-caravanserai-constructing-1` — timber frame
- (0, 3): `building-caravanserai-constructing-2` — walls with scaffolding
- (1, 0): `building-caravanserai-operational-0` — operational frame 0
- (1, 1): `building-caravanserai-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Played only while served.

## Recipe

- Recipe: `building-caravanserai` (IsoKit)
- Cell: 3×3 footprint, 176 pt tall
- Construction stages: 3
- Operational frames: 2
