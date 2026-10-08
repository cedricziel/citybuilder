---
source = "procedural"
---
## Function

The East Asian look of the low-tier residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2`
and `building-house-tier3` when the player's culture is East Asian.
Construction stages stay shared with `building-house`. No operational
animation.

## Visual identity

Single-storey hall of pale plaster between dark timber posts on a low stone base, under a wide-eaved slate hip roof whose corners turn up. Lattice windows and a sliding door, straw bales in the yard. Palette anchors: `#D2C094`/`#A89884` plaster, `#4A2F1A` posts, `#7A6B59`/`#3F2A26` roof.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, style `east-asian` in `STYLES`) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-east-asian` — canonical operational base
- (0, 1): `building-house-tier2-east-asian` — artisans: two storeys, a pent roof skirting the ground floor and a flared roof above
- (0, 2): `building-house-tier3-east-asian` — scholars: three storeys over a dark tiled plinth wall, two pent roofs and a flared crown roof on red-lacquered posts
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
