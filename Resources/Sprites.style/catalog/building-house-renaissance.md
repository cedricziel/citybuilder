---
source = "procedural"
---
## Function

The Renaissance look of the Northern European residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2` and `building-house-tier3` in the Renaissance age. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

Tall whitewashed stucco town houses whose gable ends face the street as stepped gables, cornice bands, regular rows of framed windows and terracotta roofs. Palette anchors: `#FFE9C8`/`#D2C094` stucco, `#A89884` cornices, `#A53329`/`#7A1F1A` roof.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("northern-european", "renaissance")`: the `northern-european` culture style with the renaissance age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-renaissance` — canonical operational base: narrow gable-fronted town house with a stepped gable
- (0, 1): `building-house-tier2-renaissance` — tier 2: merchant's house with paired stepped gables over a stone ground floor
- (0, 2): `building-house-tier3-renaissance` — tier 3: guild house: four-step gable, pilasters and a cornice at every storey
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
