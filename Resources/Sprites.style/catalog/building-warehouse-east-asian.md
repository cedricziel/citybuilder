---
source = "procedural"
---
## Function

The East Asian look of the bulk-goods storage building. Shown in place of
`building-warehouse` when the player's culture is East Asian.

## Visual identity

Kura storehouse: thick white plaster walls over a dark tiled plinth with a pale diagonal grid, heavy timber doors, a long flared slate roof, rice bales and a crate in the yard.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, style `east-asian` in `STYLES`) in the register pinned by `world.md` § Building register. Same 3×3 footprint and bottom anchor as
`building-warehouse`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-warehouse-east-asian` — canonical operational base
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
