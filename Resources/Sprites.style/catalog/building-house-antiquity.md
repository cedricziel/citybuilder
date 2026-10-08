---
source = "procedural"
---
## Function

The Antiquity look of the Northern European residential dwelling and its two
upgrades. Shown in place of `building-house`, `building-house-tier2` and `building-house-tier3` in the Antiquity age. Construction stages stay
shared with `building-house`. No operational animation.

## Visual identity

A stone-and-thatch longhouse: low dry-stone walls under a deep pale thatch hip roof with a smoke hole, tiny dark openings, a log pile. Palette anchors: `#A89884`/`#7A6B59` stone, `#D2C094`/`#8B5A2B` thatch.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`, `age_style("northern-european", "antiquity")`: the `northern-european` culture style with the antiquity age's materials and shapes) in the register pinned by `world.md` § Building register. Same 2×2 footprint and bottom anchor as
`building-house`.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-house-antiquity` — canonical operational base: longhouse with low stone walls and a smoke hole in the thatch
- (0, 1): `building-house-tier2-antiquity` — tier 2: longer longhouse with two doors and a timber byre lean-to
- (0, 2): `building-house-tier3-antiquity` — tier 3: chieftain's hall: high stone walls, deep thatch roof and a timber-posted gabled porch
- (0, 3): spare
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

None. Construction uses the shared `building-house-constructing-*`
frames.
