---
source = "svg"
---
## Function

Non-walkable water tile. Ships path across water; carriers never enter.
Shore buildings face water on one or more cardinal sides.

## Visual identity

Painted by `scripts/art/ground.py`. Deep teal water with a swell built from a few wave trains and sun glints. The four frames advance every wave by whole periods, so the loop has no jump. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sheet

Grid: 5 cols × 1 rows. 64×32 point tiles, rendered at @1x and @2x.

- (0, 0): `terrain-water` — canonical static base
- (0, 1): `terrain-water-0` — animation frame 0 (glint pattern A)
- (0, 2): `terrain-water-1` — animation frame 1 (glint pattern B)
- (0, 3): `terrain-water-2` — animation frame 2 (glint pattern C)
- (0, 4): `terrain-water-3` — animation frame 3 (glint pattern D)

## Animation

Four-frame water glint cycle at ~0.20s per frame.

- Glint cycle: `(0, 1)` → `(0, 2)` → `(0, 3)` → `(0, 4)`. All frames
  are placed in adjacent cells on row 0.

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`)
- Texture: `scripts/art/ground.py` (`water`)
