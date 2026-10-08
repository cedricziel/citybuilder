---
operational = "derived"
---
## Function

The first building placed on an island — the population and economic
seed. Town centre acts as a goods buffer and as the visual anchor of a
settlement. The 2-frame operational animation shows a flag waving from
its central tower.

## Visual identity

Two-storey stone-and-timber building with a small central tower
flying a red flag. Slate gable roof flanked by two smaller hipped
roofs. Wider footprint than a warehouse. Palette anchors: `#A89884`
light-stone (ashlar — reserved for the town centre's tower), `#7A6B59`
weathered stone walls, `#6E4A2A` timber half-timber framing, `#3F2A26`
slate roof, `#8B1A1A` flag-red on the small central banner. Slight
`#FFE9C8` sun-warm highlight on the tower's south face.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-town-center` — canonical operational base (flag
  at rest)
- (0, 1): `building-town-center-constructing-0` — foundation (stone
  plinth, no walls)
- (0, 2): `building-town-center-constructing-1` — walls up (no tower,
  no roof)
- (0, 3): `building-town-center-constructing-2` — roof + tower
  scaffolded (tower in scaffold; flag pole present but no flag)
- (1, 0): `building-town-center-operational-0` — flag furled (low,
  hugging pole)
- (1, 1): `building-town-center-operational-1` — flag unfurled
  (extended south-east, mid-ripple)
- (1, 2): spare
- (1, 3): spare

## Animation

Two loops: construction (one-shot) and flag-wave (forever).

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Flag-wave: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Operational frames are derived locally from the base sprite (front matter
`operational = "derived"`): the building stays pixel-identical and a chimney
smoke plume rises over the roof, so the loop never swaps one drawing for
another. The per-frame roles above describe the original AI frames.
