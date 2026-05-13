## Function

Walkable grassland tile, the dominant ground texture of the island
interior. Buildings and roads place freely on grass.

## Visual identity

Mid-green meadow with subtle dither suggesting individual grass blades.
Slight tonal variation between cells gives a "wind-rippled" feel at the
canonical isometric zoom. Palette anchors: `#5C8038` mid-tone, `#3F5C26`
shadow, `#8FB04E` sunlit highlight (sparing). No clumped flowers, no
livestock, no path wear.

## Sheet

Grid: 3 cols × 1 rows. Cells are 512×512 sheet pixels each on a
1536×512 canvas; downsamples to a 64×32 iso ground tile.

- (0, 0): `terrain-grass` — canonical static base
- (0, 1): `terrain-grass-0` — animation frame 0 (slight blade flutter)
- (0, 2): `terrain-grass-1` — animation frame 1 (blade flutter peak)

## Animation

Two-frame wind-blade flutter looping at ~0.6s per frame.

- Wind flutter: `(0, 1)` → `(0, 2)`. Frames are placed in adjacent cells
  on row 0.
