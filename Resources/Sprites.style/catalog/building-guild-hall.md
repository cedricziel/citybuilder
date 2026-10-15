---
source = "isokit"
---
## Function

Medieval age signature. Workshops within 8 tiles of an operational guild hall work 25% faster.

## Visual identity

Rendered by IsoKit in the shared light rig. A stone ground floor under two half-timbered plaster storeys and a steep tile gable roof with a bell turret on the ridge, and a guild sign with a red key on an iron arm.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-guild-hall` — canonical idle base
- (0, 1): `building-guild-hall-constructing-0` — stone pad
- (0, 2): `building-guild-hall-constructing-1` — timber frame
- (0, 3): `building-guild-hall-constructing-2` — walls with scaffolding
- (1, 0): `building-guild-hall-operational-0` — operational frame 0
- (1, 1): `building-guild-hall-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages are cut from the recipe at rising heights, with scaffold on the visible corners; the operational frames repeat the finished building.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-guild-hall` (IsoKit)
- Cell: 3×3 footprint, 224 pt tall
- Construction stages: 3
- Operational frames: 2
