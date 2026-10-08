---
source = "procedural"
---
## Function

Grows hops for the brewery. Northern European towns only.

## Visual identity

Rows of tall hop poles strung with overhead wires, green bines climbing them with pale cones, behind a low fence; a small half-timbered shed under a terracotta gable roof and hop bales on the back edge. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

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
