---
name: iso-sprite-authoring
description: Author citybuilder's isometric sprites in code, without image generation. Buildings are pre-rendered 3D recipes in Tools/IsoKit (SceneKit), terrain is generated SVG transition tiles in scripts/art, and walkers are covered too. Everything renders to PNG at true 64x32 game scale. Use when adding or fixing a building recipe, construction stage, animated part, terrain or shore tile, or any sprite in Resources/*.atlas, or when checking that art holds up at sprite scale.
---

# Iso sprite authoring

Direction (owner, #84): **pre-rendered 3D buildings on painterly 2D terrain**.
OpenSpec change: `replace-generative-sprites-with-isokit`.

```
make sprites-check                        # recipe/catalog agreement + cell fit, no GPU
make sprites                              # render migrated entries into Kit.atlas
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
  `finalize` (libimagequant into `Kit.atlas`), `compare` (tolerance).
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
- Recipes may not add lights or materials outside the finish set. `RecipeRules`
  checks every construction stage and every moving-part frame, in the tests and
  in `isokit check`.

## Light and finishes

- The rig's sun is warm (1.0, 0.80, 0.56). It multiplies every finish, so a
  base colour renders noticeably warmer and more saturated than it reads in
  code. Pick finish colours **greyer than the target**: straw thatch
  `RGB(0.55, 0.47, 0.35)` renders as weathered straw, while
  `(0.62, 0.50, 0.32)` still rendered gold.
- Judge finishes **in the game, next to the terrain**, not on a sprite sheet.
  Orange tile and gold thatch looked fine alone and hot on grass. When no
  in-game shot shows a sprite, composite it on grass sampled from a screenshot.
- Weathering reads at sprite scale through geometry: a darker, greyer eave
  course on thatch (`Finish.thatchEave`) does more than texture noise.

## Atlases and filtering (design D7)

- Kit renders go to `Resources/Kit.atlas` (`art.finalize` writes there;
  `SpriteAtlasRouting` sends migrated stems there). SpriteKit applies **one
  filtering mode to a whole atlas page**: mix `.linear` kit art and `.nearest`
  pixel art on one page and the last mode set wins for every texture on it.
- An atlas with any `@2x` art loads only its `@2x` pages on retina, so a
  1x-only sprite in it disappears (the blank sawmill icon). Kit renders always
  ship both scales; keeping them out of the legacy atlases means legacy
  sprites need no twins. The content gate flags missing and orphan `@2x`.
- Adding a family: set the brief's `source`, add its stems to
  `TextureFiltering.kitRenderedStems` (a test compares it with the catalog),
  run `make sprites`, then delete the legacy PNGs the family replaces.

## Verification (design D5)

- Renders are not byte-stable: SSAO noise and z-fighting give about 0.002/255
  between runs. Keep coplanar parts ≥ 1 cm apart.
- **Quantization dominates.** libimagequant picks a different palette for
  near-identical inputs, so two quantized renders drift apart (24 of 62 failed
  a 0.1/255 check). `art.compare` therefore compares the fresh **raw** render
  with the committed indexed PNG: mean ≤ 1.5/255, ≤ 0.3% of pixels off by > 24.
- Compare **premultiplied**: a palette's transparent entry carries arbitrary
  RGB, and a straight comparison reads that as a 38/255 mean.

## Re-render noise

`make sprites` rewrites every kit PNG, and quantization noise changes bytes even
when the art didn't change. Commit only the PNGs a change really moved: restore
the atlas, run `art.compare` on the fresh raw renders against it, and keep the
files it lists as outside tolerance.

## Terrain tiles (scripts/art/terrain_tiles.py, scripts/art/ground.py)

- Corner masks N=1/E=2/S=4/W=8 → `terrain-grass-beach-t<m>` (plus `-autumn` and
  `-winter` sets, because grass changes with the season) and
  `terrain-beach-water-t<m>`, m = 1..14, plus full tiles. Beach always
  separates grass from water. The brief of the upper terrain lists its
  transitions in its Sheet; transitions have no brief of their own.
- Boundaries cross each tile edge **at its midpoint, leaving perpendicular**.
  Wobble fades to zero at the ends. Neighbours along +col need consistent
  masks (3 next to 7, not 3 next to 6).
- **Bleed:** mask with a diamond 1 pt larger, and extend every region by
  `BLEED = 0.08` uv past the edge, or seams show as dotted lines of the wrong
  terrain. Edge strokes (fringes, foam, shallows) must stay narrow: a wide
  halo spills into the plain neighbour tile and leaves a straight step.
- **Ground textures** (`art.ground`) live in tile space (u, v) and repeat with
  period 1, so any two tiles join. Each is a small heightfield in metres plus
  an albedo, lit like the rig: warm sun with soft cast shadows, cool sky,
  glints on water. FFT-filtered white noise is periodic for free; wave trains
  with integer wave vectors loop over frames. Window anything per variant with
  `(sin πu · sin πv)²` so variants still join.
- Textures enter the SVG as a pattern skewed by `matrix(32 16 -32 16 32 0)`.
  rsvg clamps the image at pattern-cell edges, so each cell holds 2×2 repeats
  starting half a tile early; with one repeat per cell the clamp draws a seam
  along every tile edge.
- The warm sun yellows grass and turns snow cream: pick cooler albedos than
  the target (snow `(0.84, 0.90, 0.98)`). Steep relief falls into shadow and
  reads as mud; rock stays under ~1 m of relief per 4 m tile. Gridded tree
  crowns show the tile lattice; scatter them.
- Judge terrain on a composed island, not single tiles: lay real @2x tiles out
  with the D6 corner rule and put kit houses on them (season by season).
- Sandbox: shell loops over rsvg get blocked, so drive rsvg from Python.
- The seam test joins every pair of tiles whose shared corners agree, in both
  lattice directions: no gaps, and colour changes only on edges the boundary
  crosses. The content gate applies the diamond rules to every `terrain-*`
  name, wherever it lives.
## In-game before/after

Debug builds take `-uiTestSeedTown`: the seed-0 island with four finished peasant
houses beside the town center, under the default camera (`UITestSeed.townWorld`).
Build the before app from main plus that seed and the after app from the family
branch. Launch with `xcrun simctl launch <udid> com.cedricziel.citybuilder
-uiTestSeedTown`, tap New Game, then Start, wait about 15 s, and take the shot
with `simctl io screenshot`. Add `-uiTestSeason autumn` or `winter` to start
the town in that season, and `-uiTestShowcase <category>` (`gather`, `craft`,
`town`) to also place one of each kind in that build category where the rules
allow. Ask for the simulator slot first and shut the
simulator down afterwards. The HUD's money and population come from the core
simulation, so if they differ between the two shots, the builds sit on
different main commits; the art didn't cause it.

- **Light changes over time.** A day is 1200 ticks and a season 600, so spring
  and autumn start in daylight and dusk falls about 48 s into play; winter and
  summer start at night, and winter only gets daylight in its last 60 ticks.
  Leave the game timing alone. Shoot spring and autumn for lit comparisons,
  capture both builds at the same moment (the in-panel screenshot is saved
  under `tool-results/`; a later `simctl io screenshot` can already be at
  dusk), and label a winter pair as night.
- Pinch to the zoom-out limit for an island-wide shot; the limit makes the
  framing repeatable.

## Roads (scripts/art/roads.py)

- A road is a ground overlay, transparent off the road, drawn per connection
  mask (`RoadLinks` in CityRender2D, `masks()` here): arm bands of one fixed
  width to paved edge neighbours, and a corner fill only where the diagonal is
  paved too. Filling a quadrant without the diagonal reaches the tile edge
  where the neighbour has only a band, and leaves a step.
- Paved means roads plus the town center's footprint, so the starter ring paves
  up to the square; roads touching the center use the cobbled plaza surface.
- New sprite slots need `TextureFiltering.stem` to strip them (`c<mask>` like
  `v<n>` and `t<mask>`), or routing sends the files to the wrong atlas; the
  routing tests catch it.

## Checking by eye

`examples/compose_patch.py` lays sprites on a small patch. Look at 1× with
nearest 3× and at @2× before anything enters an atlas. `examples/*.svg` are the
round-1 hand SVG sprites (pixel fallback, icons).
