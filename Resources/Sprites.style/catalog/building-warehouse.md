## Function

Bulk-goods storage building used as a central buffer for the carrier
logistics network. Static silhouette — no operational animation.

## Visual identity

Long single-storey stone-and-timber storage shed with a slate gable
roof. Double cargo doors on the south face. Slightly wider footprint
than a house. Palette anchors: `#7A6B59` weathered stone walls
(lower half), `#6E4A2A` timber upper half-timbering, `#3F2A26` dark
slate roof, `#A07C50` pine plank cargo doors. No barrels or sacks
stacked outside; the storage is implied to be inside.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-warehouse` — canonical operational base
- (0, 1): `building-warehouse-constructing-0` — foundation (stone
  course laid; no walls)
- (0, 2): `building-warehouse-constructing-1` — wall framing (timber
  upper frame; roof open)
- (0, 3): `building-warehouse-constructing-2` — roof going on (slate
  half-laid; scaffolding visible)
- (1, 0): spare
- (1, 1): spare
- (1, 2): spare
- (1, 3): spare

## Animation

Construction-stage progression — not a loop.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
