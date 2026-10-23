---
source = "isokit"
---
## Function

Shore-placement ship producer. Consumes wood and planks; emits ships. This entry is the **east-facing** shipyard: the sea lies to the east of its land side (`ShoreOrientation.e`, the direction from the land-face tiles to the sea-face tiles). The footprint is two columns by three rows in every facing.

## Visual identity

Rendered by IsoKit in the shared light rig. A grey stone quay over the land half of the footprint carries a plank boat shed and a log pile. A stone slipway with timber rails steps down into the water beside the visible edge, with a hull on its cradle. While the yard operates, the hull is planked stage by stage, from keel and ribs to six strakes, then launched, and a new keel is laid. The four facings move the geometry, never the camera or the sun, so they light alike.

## Sprites

- `building-shipyard-e` — finished shipyard
- `building-shipyard-e-constructing-0` — quay and slipway
- `building-shipyard-e-constructing-1` — shed walls rising
- `building-shipyard-e-constructing-2` — shed under its roof, scaffold
- `building-shipyard-e-operational-0` — keel and ribs
- `building-shipyard-e-operational-1` — hull with two strakes
- `building-shipyard-e-operational-2` — hull with four strakes
- `building-shipyard-e-operational-3` — hull with six strakes, finished
- `building-shipyard-e-operational-4` — empty slipway, the hull launched

## Recipe

- Recipe: `building-shipyard-e` (IsoKit)
- Cell: 2×3 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 5
- Moving part: hull
