---
operational = "derived"
---
## Function

Shore-placement goods exchange. Carriers deposit/withdraw goods from
the land side; ships dock at the water side. This catalog entry is the
**north-facing** port — its sea-facing side is on the south (water tile
to the south of the building footprint).

## Visual identity

Wooden pier extending south from a stone-quay base, two-storey
half-timber warehouse on the inland (north) side. Pier deck shows
mooring bollards. South-facing wall has a wide loading door. Palette
anchors: `#7A6B59` stone quay, `#6E4A2A` timber pier and warehouse
framing, `#A07C50` pine plank deck, `#7A1F1A` terracotta roof,
`#3F2A26` slate roof underside on the warehouse. Cast shadow falls
south-east as for every building. The 2-frame operational animation
shows a small banner on the warehouse roof waving in the sea breeze.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-port-n` — canonical operational base
- (0, 1): `building-port-n-constructing-0` — pilings driven (timber
  posts in water, no deck)
- (0, 2): `building-port-n-constructing-1` — deck laid + stone quay
  built; no warehouse
- (0, 3): `building-port-n-constructing-2` — warehouse framing up;
  roof open
- (1, 0): `building-port-n-operational-0` — banner low
- (1, 1): `building-port-n-operational-1` — banner unfurled
- (1, 2): spare
- (1, 3): spare

## Animation

Two loops: construction (one-shot) and banner-wave (forever).

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Banner-wave: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Operational frames are derived locally from the base sprite (front matter
`operational = "derived"`): the building stays pixel-identical and a chimney
smoke plume rises over the roof, so the loop never swaps one drawing for
another. The per-frame roles above describe the original AI frames.
