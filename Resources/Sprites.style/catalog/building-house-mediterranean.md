---
source = "procedural"
---
## Function

The Mediterranean look of the low-tier residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2`
and `building-house-tier3` when the player's culture is Mediterranean.
Construction stages stay shared with `building-house`. No operational
animation.

## Visual identity

Whitewashed cottage under a low-pitched terracotta hip roof, no timber framing. Blue shutters and a blue door, a whitewashed chimney with a terracotta cap, two amphorae in the yard. Palette anchors: `#FFE9C8` whitewash lit wall, `#D2C094` shaded wall, `#A53329`/`#7A1F1A` roof tile, `#3F6E94` shutters.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, style `mediterranean` in `STYLES`) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-mediterranean` — canonical operational base
- (0, 1): `building-house-tier2-mediterranean` — citizens: whitewashed two-storey house with an arcaded ground-floor loggia under a low hip roof
- (0, 2): `building-house-tier3-mediterranean` — patricians: three storeys on a stone ground floor, a balcony, and a belvedere tower with an open loggia
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
