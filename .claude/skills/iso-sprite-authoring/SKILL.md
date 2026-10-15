---
name: iso-sprite-authoring
description: Author citybuilder's isometric sprites by hand or in code, without image generation. Covers buildings as pre-rendered SceneKit 3D, terrain tiles and shore/grass transitions as SVG, and walkers. Renders them to PNG at true 64x32 game scale. Use when drawing, fixing or adding any sprite in Resources/*.atlas, or when checking that a look holds up at sprite scale.
---

# Iso sprite authoring

Working examples are in `examples/`: `house3d.swift` (3D route),
`tile-*.svg`, `house.svg`, `walker.svg`, and `compose_patch.py` (lays the
sprites out on a patch the way SpriteKit draws them).

## Grid and anchors (from the code)

- Tile 64×32 (`IsoMath.tileWidth/Height`, `Packages/CityRender2D`). Tile (c,r)
  top corner at `(32(c-r), 16(c+r))`; +c = screen down-right, +r = down-left.
- Building sprite: anchor `(0.5, 0)` = **bottom-centre = footprint bottom corner**.
  Width = 64 × footprint (2×2 house → 128). Today's house cell is 128×94; the
  proof used 128×112 to fit a chimney.
- Textures use `.nearest` filtering. A 1× sprite is shown at about 3× on
  iPhone, so always review at 3×.
- Walker 8×12 is too small; 10×16 reads (hat, load). Origin = feet.

## Route 1: buildings as pre-rendered 3D (chosen)

`xcrun swift examples/house3d.swift <out> <scale> [b]` takes about 3 s and
needs no project build. Never use bare `swift`.

- **Camera (2:1 dimetric):** orthographic, `eulerAngles = (-30°, 45°, 0)`.
  sin 30° = ½ gives the 2:1 squash. World x = +c, z = +r, y = up, 1 tile = 4 m,
  so `pxPerMetre = 64 / (4·√2) = 11.31` at 1×.
  `orthographicScale = spriteH/2 / pxPerMetre`. Put the camera at
  `anchor + up·(spriteH/2/pxPerMetre) − forward·60`, with
  `up = (−½/√2, cos30°, −½/√2)` and `forward = (−cos30°/√2, −½, −cos30°/√2)`.
- **Light rig (shared by every building):** directional sun
  `(1.0, 0.84, 0.64)` at 2600 from `(−9, 30, +9)` relative to the footprint
  centre (screen upper-left, high enough that the shadow stays inside the
  cell). Soft shadows: 4096 map, 16 samples, radius 4. Ambient sky
  `(0.66, 0.68, 0.78)` at 480; lower and the shade walls go black. Camera SSAO
  1.4 / radius 0.5, HDR, exposure −0.3.
- **Materials:** `.physicallyBased`, roughness 0.7–0.95, metalness 0.
  Procedural CGContext textures with a seeded LCG for speckled plaster, stone
  and timber, and staggered roof tiles. On an `SCNBox` slab, u runs down the
  slope: rotate the roof texture 90° so courses run along the ridge. Lit
  windows get emission.
- **Ground:** `SCNFloor` with `.shadowOnly`, background `NSColor.clear`. The
  cast shadow lands in the sprite's alpha.
- **Size:** render at 4× the target, then downsample with `.high`
  interpolation. That bakes clean edges, which survive nearest upscaling.
- **Consistency:** a building = a kit of parts (body, gable, roof slabs,
  timber frame, window, door, chimney, plinth, clutter) + parameters. Variants
  are flags (`b` = slate roof, pale plaster), not new code.
- **Animation:** render frames by moving parts (mill sails, saw), and
  construction stages by hiding parts. Keep smoke as SpriteKit particles.

## Route 2: terrain as SVG tiles

- `shape-rendering="crispEdges"` on every tile. Anti-aliased diamond edges
  leave dark seams once composited.
- Texture `<pattern>` period must divide **32×16**, or neighbours (offset
  32,16) won't line up. Never use feTurbulence in a tile; it does not tile.
- Transition tiles: the boundary meets the tile edges at their midpoints
  (16,8) and (48,24), so it continues into the next tile. Layer order for
  sand→water: shallow water, wet-sand band (darker), dry sand, foam line
  (≈1.6 px, `#F4F1E4`), and a fainter second foam line in the water.
  Grass→sand: a yellow-green fringe under ragged grass, plus tufts.
- The renderer draws one type per tile today. Transitions need a renderer
  change (Round 2).

## Route 3: hand SVG sprites (fallback / icons)

- Origin = footprint top corner; the base inset is 1 m (8 px on a 2×2). Walls
  are about 30 px; ridge parallel to the +c edge. Light the left wall, shade
  the right wall, and keep the gable on the right.
- Keep the blurred cast shadow ≥ 2 px inside the cell. Sit chimneys on the
  roof surface (check the y of the back slope at that x).
- Pixel variant: world.md palette, 1 px `#1A1410` outline, `crispEdges`.

## Check every sprite

`python3 -I examples/compose_patch.py examples <out> [house3d]` (the optional
arg swaps in `<out>/house3d@{1,3}x.png` rendered beforehand) writes
`patch@1x-nearest3x.png` (what the game shows) and `patch@3x.png`. Look at
both before a sprite goes into an atlas.
