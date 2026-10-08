---
operational = "derived"
---
## Function

Shore-placement goods exchange. Carriers deposit/withdraw goods from
the land side; ships dock at the water side. This catalog entry is the
**west-facing** port — its sea-facing side is on the east (water tile
to the east of the building footprint).

## Visual identity

Wooden pier extending east from a stone-quay base; warehouse on the
inland (west) side with the loading door on its east face. Palette,
silhouette register, and outline weight MUST match `building-port-n.md`.
Cast shadow falls south-east as for every building. 2-frame banner
wave.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-port-w` — canonical operational base
- (0, 1): `building-port-w-constructing-0` — pilings driven
- (0, 2): `building-port-w-constructing-1` — deck + quay
- (0, 3): `building-port-w-constructing-2` — warehouse framing
- (1, 0): `building-port-w-operational-0` — banner low
- (1, 1): `building-port-w-operational-1` — banner unfurled
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Banner-wave: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Operational frames are derived locally from the base sprite (front matter
`operational = "derived"`): the building stays pixel-identical and a chimney
smoke plume rises over the roof, so the loop never swaps one drawing for
another. The per-frame roles above describe the original AI frames.
