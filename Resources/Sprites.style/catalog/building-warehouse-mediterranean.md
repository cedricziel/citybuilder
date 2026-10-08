---
source = "procedural"
---
## Function

The Mediterranean look of the bulk-goods storage building. Shown in place of
`building-warehouse` when the player's culture is Mediterranean.

## Visual identity

Long whitewashed storehouse under a low terracotta hip roof, two big arched cargo doors, small shuttered windows, amphorae and a crate in the yard.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, style `mediterranean` in `STYLES`) in the register pinned by `world.md` § Building register. Same 3×3 footprint and bottom anchor as
`building-warehouse`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-warehouse-mediterranean` — canonical operational base
- (0, 1): spare
- (0, 2): spare
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-warehouse-constructing-*`
frames.
