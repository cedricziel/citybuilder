---
source = "isokit"
---
## Function

Shore-placement goods exchange. Carriers deposit and withdraw goods on the land side; ships dock at the water side. This entry is the **north-facing** port: the sea lies to the north of its land side (`ShoreOrientation.n`, the direction from the land-face tiles to the sea-face tiles). The footprint is two columns by three rows in every facing.

## Visual identity

Rendered by IsoKit in the shared light rig. A grey stone quay over the land half of the footprint carries a timber-framed plaster warehouse under a red tile roof and a timber crane whose jib reaches over the water, with crates and barrels. A plank wharf on pilings covers the seaward half, so it stands over the water wherever the shoreline crosses the footprint. The four facings move the geometry, never the camera or the sun, so they light alike.

## Sheet

Grid: 4 cols × 2 rows. Default sheet size.

- (0, 0): `building-port-n` — finished port
- (0, 1): `building-port-n-constructing-0` — quay and wharf
- (0, 2): `building-port-n-constructing-1` — warehouse walls rising
- (0, 3): `building-port-n-constructing-2` — warehouse under its roof, scaffold
- (1, 0): `building-port-n-operational-0` — operational frame 0
- (1, 1): `building-port-n-operational-1` — operational frame 1
- (1, 2): spare
- (1, 3): spare

## Animation

Construction stages: the quay and wharf are there from the start, and the warehouse and crane rise through rising cuts with scaffold on the visible corners. The operational frames repeat the finished port.

- Construction: `(0, 1)` → `(0, 2)` → `(0, 3)`. Adjacent on row 0.
- Operational: `(1, 0)` → `(1, 1)`. Adjacent on row 1.

## Recipe

- Recipe: `building-port-n` (IsoKit)
- Cell: 2×3 footprint, 128 pt tall
- Construction stages: 3
- Operational frames: 2
