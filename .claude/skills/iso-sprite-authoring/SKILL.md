---
name: iso-sprite-authoring
description: Author citybuilder's isometric sprites in code, without image generation. Buildings are pre-rendered 3D recipes in Tools/IsoKit (SceneKit), terrain is generated SVG transition tiles in scripts/art, and walkers are covered too. Everything renders to PNG at true 64x32 game scale. Use when adding or fixing a building recipe, construction stage, animated part, terrain or shore tile, or any sprite in Resources/*.atlas, or when checking that art holds up at sprite scale.
---

# Iso sprite authoring

Direction (owner, #84): **pre-rendered 3D buildings on painterly 2D terrain**.
OpenSpec change: `replace-generative-sprites-with-isokit`.

```
make sprites-check                        # recipe/catalog agreement + cell fit, no GPU
make sprites                              # render migrated entries into the atlases
make sprites-verify                       # tolerance check + legacy byte check + content gate
xcrun swift run --package-path Tools/IsoKit isokit render --all --out /tmp/r   # every recipe, scratch
ISOKIT_SKIP_RENDER=1 xcrun swift test --package-path Tools/IsoKit             # CI's view
```

Never bare `swift`. Rendering needs a Mac GPU; CI never renders.

## Where things live

- `Tools/IsoKit/Sources/IsoKitCore`: `Geometry` (2:1 maths, `SpriteCell`),
  `Rig` (sun, sky, camera), `Renderer`, `Materials` (finishes), `Parts`,
  `Props`, `Recipe` (stages, moving parts, plot), `Catalog`, `CellFit`,
  `RenderJob`, and `Recipes/` (one recipe per building look).
- `scripts/art`: `terrain_tiles` (corner-mask SVG), `svg_sprites` (rsvg),
  `finalize` (libimagequant into the atlases), `compare` (tolerance).
- A catalog brief (`Resources/Sprites.style/catalog/<id>.md`) migrates by
  setting `source = "isokit"` (or `"svg"`). Until then the legacy pipeline owns
  its PNGs, and `make sprites` leaves them alone.

## Grid and anchors (from the code)

- Tile 64×32 (`IsoMath`, `Packages/CityRender2D`). Tile (c,r) top corner at
  `(32(c-r), 16(c+r))`; +c = screen down-right, +r = down-left.
- Building cell: n×n footprint → **64n pt wide**; anchor `(0.5, 0)` =
  footprint bottom vertex. Each recipe declares its height; `CellFit` projects
  every geometry corner and fails a clipped stage (`isokit check`).
- Walkers: 10×16 (8×12 is too small to read).

## Recipes

- A recipe is parts + numbers, 19–38 lines. `id` is the sprite stem; `entry`
  is the catalog brief. One brief can own several recipes (house tiers).
- The rendered names must equal the brief's Sheet list, or `isokit check`
  fails. Mirror the atlas you replace: count the `-constructing-N` and
  `-operational-N` files that exist today.
- **Plot:** every recipe gets a slab over its whole footprint, 3 cm below yard
  slabs (no z-fighting), overhanging the two front edges by 12 cm. Without it,
  inset buildings never touch the bottom vertex (`not_grounded`), and a bare
  diamond tip is ~2 px wide, so its alpha flickers between renders.
- Decorate only **south (+z) and east (+x)** faces; the camera never sees the rest.
- Roof slabs (`SCNBox`) map u down the slope: rotate the texture 90°.
  Hip-roof polygons get their own UVs, so no rotation.
- Thin slabs map V across their top face, or cobbles turn into stripes.
- **Construction stages:** recipes that don't stage themselves are cut at
  rising heights, with scaffold poles on the **three visible corners** of the
  structure. Paving doesn't count as structure, and a pole on the hidden back
  corner projects above the cell.
- **Moving parts** (sails, saws): overlay frames with the building drawn
  depth-only and no ground, composited onto the idle sprite as
  `-operational-N`. Four-blade sails repeat every 90°, so 4 frames make a turn.
- Recipes may not add lights or materials outside the finish set (tests check).

## Verification (design D5)

- Renders are not byte-stable: SSAO noise and z-fighting give about 0.002/255
  between runs. Keep coplanar parts ≥ 1 cm apart.
- **Quantization dominates.** libimagequant picks a different palette for
  near-identical inputs, so two quantized renders drift apart (24 of 62 failed
  a 0.1/255 check). `art.compare` therefore compares the fresh **raw** render
  with the committed indexed PNG: mean ≤ 1.5/255, ≤ 0.3% of pixels off by > 24.
- Compare **premultiplied**: a palette's transparent entry carries arbitrary
  RGB, and a straight comparison reads that as a 38/255 mean.

## Terrain tiles (scripts/art/terrain_tiles.py)

- Corner masks N=1/E=2/S=4/W=8 → `terrain-grass-beach-t<m>` and
  `terrain-beach-water-t<m>`, m = 1..14, plus full tiles. Beach always
  separates grass from water.
- Boundaries cross each tile edge **at its midpoint, leaving perpendicular**.
  Wobble fades to zero at the ends. Neighbours along +col need consistent
  masks (3 next to 7, not 3 next to 6).
- **Bleed:** mask with a diamond 1 pt larger, and extend every region by
  `BLEED = 0.08` uv past the edge, or seams show as dotted lines of the wrong
  terrain.
- Pattern period must divide **32×16**. Per-tile clutter stays within uv
  0.2–0.8. Never use feTurbulence in tiles.
- Sandbox: shell loops over rsvg get blocked, so drive rsvg from Python.

## Checking by eye

`examples/compose_patch.py` lays sprites on a small patch. Look at 1× with
nearest 3× and at @2× before anything enters an atlas. `examples/*.svg` are the
round-1 hand SVG sprites (pixel fallback, icons).
