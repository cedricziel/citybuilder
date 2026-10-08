---
source = "procedural"
---
## Function

Shore-placement goods exchange. Carriers deposit/withdraw goods from
the land side; ships dock at the water side. This catalog entry is the
**south-facing** port — its sea-facing side is on the north (water tile
to the north of the building footprint).

## Visual identity

Wooden pier extending north from a stone-quay base, two-storey
half-timber warehouse on the inland (south) side. The warehouse south
face presents the loading door to the camera. Palette and silhouette
register MUST match `building-port-n.md` so all four orientations read
as the same building reskinned for direction. Cast shadow falls
south-east as for every building. 2-frame banner wave.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-port-s` — canonical operational base
- (0, 1): `building-port-s-constructing-0` — pilings driven
- (0, 2): `building-port-s-constructing-1` — deck + quay
- (0, 3): `building-port-s-constructing-2` — warehouse framing
- (1, 0): `building-port-s-operational-0` — banner low
- (1, 1): `building-port-s-operational-1` — banner unfurled
- (1, 2): spare
- (1, 3): spare

## Animation

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Banner-wave: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

Drawn by the procedural building kit (`scripts/generate_sprites_ai/buildings.py`,
`units.py`) in the register pinned by `world.md` § Building register.
Operational frames keep the finished building and add a rising smoke plume.
The per-cell roles above describe the original AI sprites.
