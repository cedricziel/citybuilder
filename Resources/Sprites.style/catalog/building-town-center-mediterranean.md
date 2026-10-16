---
source = "isokit"
---
## Function

The Mediterranean look of the first building placed on an island and the settlement's goods buffer. Shown in place of
`building-town-center` when the player's culture is Mediterranean.

## Visual identity

Rendered by IsoKit in the shared light rig. A whitewashed hall under a low terracotta hip roof beside a square campanile: a stone footing, an open arched belfry and a low pyramid tile roof. Arched door and blue-shuttered windows. Same 3×3 footprint and bottom anchor as `building-town-center`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-town-center-mediterranean` — canonical operational base
- (0, 1): spare
- (0, 2): spare
- (0, 3): spare
- (1, 0): `building-town-center-mediterranean-operational-0` — operational frame 0
- (1, 1): `building-town-center-mediterranean-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

The operational frames repeat the finished building.

- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
- Construction uses the shared `building-town-center-constructing-*` frames.

## Recipe

- Recipe: `building-town-center-mediterranean` (IsoKit)
- Cell: 3×3 footprint, 224 pt tall
- Construction stages: 0
- Operational frames: 2
