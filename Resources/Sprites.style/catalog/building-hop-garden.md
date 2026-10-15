---
source = "isokit"
---
## Function

Grows hops for the brewery. Northern European towns only.

## Visual identity

Rendered by IsoKit in the shared light rig. A half-timbered shed under a tile roof, and tall hop poles in rows with green bines climbing them, pale cones and the overhead wires along each row.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-hop-garden` — canonical operational base
- (0, 1): `building-hop-garden-constructing-0` — stone pad
- (0, 2): `building-hop-garden-constructing-1` — timber frame
- (0, 3): `building-hop-garden-constructing-2` — walls with scaffolding
- (1, 0): `building-hop-garden-operational-0` — operational frame 0
- (1, 1): `building-hop-garden-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-hop-garden` (IsoKit)
- Cell: 2×2 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 2
