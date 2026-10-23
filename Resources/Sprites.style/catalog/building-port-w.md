---
source = "isokit"
---
## Function

Shore-placement goods exchange. Carriers deposit and withdraw goods on the land side; ships dock at the water side. This entry is the **west-facing** port: the sea lies to the west of its land side (`ShoreOrientation.w`, the direction from the land-face tiles to the sea-face tiles). The footprint is two columns by three rows in every facing.

## Visual identity

Rendered by IsoKit in the shared light rig. A grey stone quay over the land half of the footprint carries a timber-framed plaster warehouse under a red tile roof and a timber crane whose jib reaches over the water, with crates and barrels. A plank wharf on pilings covers the seaward half, so it stands over the water wherever the shoreline crosses the footprint. The four facings move the geometry, never the camera or the sun, so they light alike.

## Sprites

- `building-port-w` — finished port
- `building-port-w-constructing-0` — quay and wharf
- `building-port-w-constructing-1` — warehouse walls rising
- `building-port-w-constructing-2` — warehouse under its roof, scaffold
- `building-port-w-operational-0` — the finished port, operational

## Recipe

- Recipe: `building-port-w` (IsoKit)
- Cell: 2×3 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 1
