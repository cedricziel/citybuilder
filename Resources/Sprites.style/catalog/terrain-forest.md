---
source = "svg"
---
## Function

Non-walkable forest tile. Lumberjack huts extract wood from adjacent
forest tiles; carriers route around them. Buildings cannot place on
forest.

## Visual identity

Painted by `scripts/art/ground.py`. A loose canopy of broadleaf crowns in five greens and three sizes among darker conifers, scattered so the tile repeat is hard to see, with small clearings where the floor shows. Shallow relief keeps it light enough to read next to the grass. Lit like the IsoKit rig (warm sun from the upper left, cool sky) and repeating once per tile in (u, v), so any two tiles join without a seam.

## Sheet

Grid: 1 cols × 1 rows. 64×32 point tiles, rendered at @1x and @2x.

- (0, 0): `terrain-forest` — canonical static tile

## Animation

Static — no animation loop.

## Recipe

- SVG generator: `scripts/art/terrain_tiles.py` (`full`)
- Texture: `scripts/art/ground.py` (`forest`)
