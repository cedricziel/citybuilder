---
source = "isokit"
---
## Function

Shore-placement goods exchange. Carriers deposit and withdraw goods on the land side; ships dock at the water side. This entry is the **east-facing** port: the sea lies to the east of its land side (`ShoreOrientation.e`, the direction from the land-face tiles to the sea-face tiles). The footprint is two columns by three rows in every facing.

## Visual identity

Rendered by IsoKit in the shared light rig. A grey stone quay over the land half of the footprint carries a timber-framed plaster warehouse under a red tile roof and a timber crane, with crates and barrels. While the port operates, the crane lifts a crate off the wharf, swings it round onto the quay beside the warehouse, sets it down and swings back out. A plank wharf on pilings covers the seaward half, so it stands over the water wherever the shoreline crosses the footprint. The four facings move the geometry, never the camera or the sun, so they light alike.

## Sprites

- `building-port-e` — finished port
- `building-port-e-constructing-0` — quay and wharf
- `building-port-e-constructing-1` — warehouse walls rising
- `building-port-e-constructing-2` — warehouse under its roof, scaffold
- `building-port-e-operational-0` — crate on the wharf, jib over the water
- `building-port-e-operational-1` — crate lifted
- `building-port-e-operational-2` — crane swinging toward the quay
- `building-port-e-operational-3` — crate over the quay
- `building-port-e-operational-4` — crate set down on the quay
- `building-port-e-operational-5` — crane swinging back out

## Recipe

- Recipe: `building-port-e` (IsoKit)
- Cell: 2×3 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 6
- Moving part: crane
