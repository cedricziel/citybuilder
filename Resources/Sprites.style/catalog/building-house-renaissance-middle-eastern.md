---
source = "procedural"
---
## Function

The Renaissance look of the Middle Eastern residential dwelling and its two
upgrades. Shown in place of `building-house-middle-eastern`, `building-house-tier2-middle-eastern` and `building-house-tier3-middle-eastern` in the Renaissance age when the player's culture is Middle Eastern. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Carved stone houses: pale ashlar with cornice bands, pointed-arch windows framed in pale stone, projecting wooden mashrabiya bays and flat roofs; a small blue-tiled dome crowns the largest. Palette anchors: `#D2C094`/`#A89884` stone, `#4A2F1A` lattice, `#6FA4C2`/`#3F6E94` dome.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("middle-eastern", "renaissance")`: the `middle-eastern` culture style with the renaissance age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-renaissance-middle-eastern` — canonical operational base: stone house with one mashrabiya bay
- (0, 1): `building-house-tier2-renaissance-middle-eastern` — tier 2: three storeys with paired mashrabiya bays
- (0, 2): `building-house-tier3-renaissance-middle-eastern` — tier 3: mansion with three mashrabiya bays and a small tiled dome
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
