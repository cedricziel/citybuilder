## Function

Forest-extraction building. A lumberjack walker spawns from this hut
and harvests wood from adjacent forest tiles. The operational
animation shows an axe-swing rhythm to communicate "actively working"
from a distance.

## Visual identity

Small one-room timber-frame shed with a thatch roof. Open south face
(no door visible) revealing a chopping block. A leaning pile of split
logs against the east wall. Smaller silhouette than house. Palette
anchors: `#6E4A2A` timber frame, `#8B5A2B` thatch roof, `#A07C50` fresh
pine plank stacked logs, `#D4A86A` interior wall planks. A small wisp
of `#7A6B59` smoke from a south-side chimney lift in the second
operational frame only.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-lumberjack-hut` — canonical operational base
- (0, 1): `building-lumberjack-hut-constructing-0` — foundation (stone
  pad + corner posts)
- (0, 2): `building-lumberjack-hut-constructing-1` — frame raised
  (timber skeleton, no roof)
- (0, 3): `building-lumberjack-hut-constructing-2` — thatching
  (half-thatched roof + scaffolding)
- (1, 0): `building-lumberjack-hut-operational-0` — axe up (lumberjack
  silhouette mid-swing, no smoke)
- (1, 1): `building-lumberjack-hut-operational-1` — axe down (chopping
  block flares; small smoke wisp from chimney)
- (1, 2): spare
- (1, 3): spare

## Animation

Two animation loops: construction (one-shot) and operational (forever).

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.
