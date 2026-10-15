---
source = "isokit"
---
## Function

Shore-placement ship producer. Consumes wood and planks; emits ships. This entry is the **north-facing** shipyard: the sea lies to the north of its land side (`ShoreOrientation.n`, the direction from the land-face tiles to the sea-face tiles). The footprint is two columns by three rows in every facing.

## Visual identity

Rendered by IsoKit in the shared light rig. A grey stone quay over the land half of the footprint carries a plank boat shed and a log pile. A stone slipway with timber rails steps down into the water beside the visible edge, with a hull on its cradle: keel and ribs, and strakes being fitted. The four facings move the geometry, never the camera or the sun, so they light alike.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-shipyard-n` — finished shipyard
- (0, 1): `building-shipyard-n-constructing-0` — quay and slipway
- (0, 2): `building-shipyard-n-constructing-1` — shed walls rising
- (0, 3): `building-shipyard-n-constructing-2` — shed under its roof, scaffold
- (1, 0): `building-shipyard-n-operational-0` — hull with two strakes
- (1, 1): `building-shipyard-n-operational-1` — hull with four strakes
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages: the quay and slipway are there from the start, and the shed rises through rising cuts with scaffold on the visible corners; the hull appears once the yard is finished. The operational frames plank the hull: two strakes, then four.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-shipyard-n` (IsoKit)
- Cell: 2×3 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 2
- Moving part: hull
