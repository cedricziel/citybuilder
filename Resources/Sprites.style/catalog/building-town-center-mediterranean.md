---
source = "procedural"
---
## Function

The Mediterranean look of the first building placed on an island and the settlement's goods buffer. Shown in place of
`building-town-center` when the player's culture is Mediterranean.

## Visual identity

Whitewashed hall under a low terracotta hip roof beside a square campanile: a tall whitewashed bell tower with a stone footing, an open arched belfry with bells, and a low pyramid tile roof. Arched door and blue-shuttered windows.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, style `mediterranean` in `STYLES`) in the register pinned by `world.md` § Building register. Same 3×3 footprint and bottom anchor as
`building-town-center`.

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

- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1. Frames keep the
  finished building pixel-identical and add a rising smoke plume.
- Construction uses the shared `building-town-center-constructing-*` frames.
