---
source = "procedural"
---
## Function

Medieval age signature. Workshops within 8 tiles of an operational guild hall work 25% faster.

## Visual identity

A stone ground floor under two half-timbered plaster storeys and a steep terracotta gable roof with a bell turret on the ridge; a guild sign with a red key hangs from an iron arm. Drawn by the procedural building kit in the register pinned by
`world.md` § Building register.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-guild-hall` — canonical idle base
- (0, 1): `building-guild-hall-constructing-0` — stone pad
- (0, 2): `building-guild-hall-constructing-1` — timber frame
- (0, 3): `building-guild-hall-constructing-2` — walls with scaffolding
- (1, 0): `building-guild-hall-operational-0` — sign swinging west
- (1, 1): `building-guild-hall-operational-1` — sign swinging east
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
