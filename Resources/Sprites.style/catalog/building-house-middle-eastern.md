---
source = "procedural"
---
## Function

The Middle Eastern look of the low-tier residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2`
and `building-house-tier3` when the player's culture is Middle Eastern.
Construction stages stay shared with `building-house`. No operational
animation.

## Visual identity

Sandstone cottage with a flat roof behind a parapet rim, small arched windows, a blue-framed arched door under a striped awning, a sack and a date palm in the yard. Palette anchors: `#C9A671` sandstone lit wall, `#8C6A45` shaded wall, `#D2C094` parapet cap, `#A07C50` roof deck.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, style `middle-eastern` in `STYLES`) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-middle-eastern` — canonical operational base
- (0, 1): `building-house-tier2-middle-eastern` — craftsmen: two storeys with a projecting wooden lattice bay and a rooftop room behind its own parapet
- (0, 2): `building-house-tier3-middle-eastern` — merchants: three storeys with two lattice bays and a slotted wind tower on the roof
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
