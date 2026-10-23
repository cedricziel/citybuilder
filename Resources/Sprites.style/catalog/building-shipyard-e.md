---
source = "isokit"
---
## Function

Shore-placement ship producer. Consumes wood and planks; emits ships. This entry is the **east-facing** shipyard: the sea lies to the east of its land side (`ShoreOrientation.e`, the direction from the land-face tiles to the sea-face tiles). The footprint is two columns by three rows in every facing.

## Visual identity

Rendered by IsoKit in the shared light rig. A grey stone quay over the land half of the footprint carries a plank boat shed and a log pile. A stone slipway with timber rails steps down into the water beside the visible edge, with a hull on its cradle: keel and ribs, and strakes being fitted. The four facings move the geometry, never the camera or the sun, so they light alike.

## Sprites

- `building-shipyard-e` — finished shipyard
- `building-shipyard-e-constructing-0` — quay and slipway
- `building-shipyard-e-constructing-1` — shed walls rising
- `building-shipyard-e-constructing-2` — shed under its roof, scaffold
- `building-shipyard-e-operational-0` — hull with two strakes
- `building-shipyard-e-operational-1` — hull with four strakes

## Recipe

- Recipe: `building-shipyard-e` (IsoKit)
- Cell: 2×3 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 2
- Moving part: hull
