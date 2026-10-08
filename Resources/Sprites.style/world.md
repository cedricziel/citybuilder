# Citybuilder — World Style Bible

This file is the single source of truth for the game's visual identity. Every
sprite generation prompt — terrain, building, walker, ship, goods icon — is
composed from this document plus a per-sprite catalog entry under
`Resources/Sprites.style/catalog/<id>.md`. The pipeline runner (see
`scripts/generate_sprites_ai/`) MUST NOT inject any visual-style directive that
is not declared here.

When in doubt, the rule for editing this file is: change one paragraph, then
run `make sprites`, then visually review every regenerated atlas PNG. A change
to this file invalidates every cache entry by design.

## Theme & era

A late-medieval North-European coastal town circa 1450 — half-timbered houses
in a tight grid behind a stone harbour wall, fishing boats moored at wooden
piers, sawmills and lumberjack huts working a green-brown forest hinterland.
The aesthetic is Anno 1602 / Stronghold Crusader / Caesar III: chunky pixel
art with crisp pixel boundaries, never blurry, never anti-aliased, never
photographic. The world reads as a single inhabited place — every sprite
belongs to the same town, in the same season, lit by the same warm afternoon
sun.

## Visual references

- **Anno 1602 (1998, Sunflowers Interactive)** — primary anchor. Especially
  the warm earth-tones of its terrain palette, the half-timber-and-thatch
  rendering of low-tier residences, and its iconic high-contrast outlines.
- **Stronghold Crusader (2002, Firefly Studios)** — secondary anchor for
  building shadow placement (sharp 45° south-east shadow) and for the
  silhouette register of working-class structures (sawmill, mill).
- **Caesar III (1998, Impressions Games)** — tertiary anchor for ground-tile
  variation patterns (subtle per-tile texture without losing the grid).
- **Ostriv / Foundation early-access screenshots** — useful only as
  reference for *roof tile pattern density*, NOT for palette (those games
  are too warm-modern; ours is colder-medieval).

Pure references — do not imitate any of these games' iconography wholesale,
and do not regurgitate their UI fonts, water shaders, or particle effects.

## Projection & scale

- **Projection.** Isometric 2:1 (true pixel-art iso, not 3D-rendered iso).
  All sprites are drawn at a 2:1 horizontal-to-vertical ratio on the tile
  grid. A single ground tile is 64×32 pixels at the canonical zoom.
- **Camera angle.** Looking down at a fixed 30° tilt, from the south-east.
  Every building's south and east walls are visible; the north and west
  walls are implied. Shadows fall south-east, length ≈ 0.4× the casting
  object's pixel height.
- **Sprite cell size.** Buildings render into a 384×512-pixel cell at sheet
  resolution (downsampled to 128×170 at canonical zoom). Goods icons render
  into a 256×256-pixel cell (downsampled to 24×24). Walker and ship cells
  are 384×512 like buildings.
- **Pixel grain.** All sprites are drawn so a 4×4 sheet pixel reads as a
  single canonical pixel after downsampling. No sub-pixel detail; no
  textures that depend on alpha gradients.

## Palette

The game's palette is warm-medieval with a cooler maritime register for water
and stone. All sprite generation MUST quantize to the following 32-colour
palette after the chroma-key pass. Colours are listed in hex with role tags.

### Earth & vegetation
- `#3D2A1D` — dark loam (under-shadow, deep tilled earth)
- `#5C3F28` — medium loam (path edges, dirt road)
- `#8C6A45` — light loam (sun-lit topsoil, beach inland edge)
- `#C9A671` — sand (beach core, dry mortar)
- `#5C8038` — leaf-green (forest, grass mid-tone)
- `#3F5C26` — shadow-green (forest under-canopy, grass deep shadow)
- `#8FB04E` — sun-grass (grass tile sunlit highlight)

### Stone & timber
- `#7A6B59` — weathered stone (harbour walls, town-centre plinth)
- `#5C5046` — shadow stone (stone in deep shadow)
- `#A89884` — light stone (cathedral-grade ashlar — reserved for town centre)
- `#6E4A2A` — timber beam (half-timber framing, wooden piers, scaffolding)
- `#4A2F1A` — dark timber (load-bearing beams, ship hull below waterline)
- `#A07C50` — pine plank (fresh-cut planks, sawmill output, new construction)
- `#D4A86A` — light wood (interior plaster panels behind half-timber)

### Roofing & textile
- `#7A1F1A` — terracotta tile (low-tier house roof)
- `#A53329` — sun-lit terracotta (south-facing roof highlight)
- `#3F2A26` — dark slate (warehouse, port roof shadow side)
- `#8B5A2B` — thatch (lumberjack hut, low-tier shore hut)
- `#D2C094` — cream linen (sail-cloth, flag base)
- `#8B1A1A` — flag-red (town flag, banners — restricted, max 4×4 px per use)

### Water & sky
- `#2A4E6E` — deep water (open sea below 3 tiles depth)
- `#3F6E94` — mid water (coastal water, 1–2 tiles depth)
- `#6FA4C2` — shallow water (one-tile shore band)
- `#A8CCDD` — foam (wave crests, hull-water boundary — max 2 px width)

### Highlight & shadow neutrals
- `#1A1410` — pure shadow / outline (deepest part of any outline; never use
  for fill)
- `#FFE9C8` — sun-warm highlight (where the sun directly hits painted wood,
  ship sails, white plaster)

The pipeline post-processor quantizes every generated sheet against this
palette. Colours that fall outside it are clamped to the nearest declared
hex.

## Outline & shading

- **Outline weight.** Every sprite has a 1-canonical-pixel (4 sheet pixels)
  dark outline on its south, east, and bottom edges. North and west edges
  use a 1-canonical-pixel mid-tone outline. The outline colour is
  `#1A1410` (pure shadow) on the lit side and the structure's own dark
  shade on the unlit side.
- **Shading.** Two-tier shading: a mid-tone (the palette role colour) and a
  shadow tier (the role's dark variant). No anti-aliased gradients. No
  third tier. Highlights appear only on metal, sails, and freshly-cut
  wood; everywhere else the mid-tone IS the bright tier.
- **Dither.** Used sparingly to suggest texture, not gradient. Acceptable
  on stone (≤10% dither density) and water (≤20%). Forbidden on flat wood,
  thatch, and human figures.
- **Cast shadow.** Buildings cast a sharp 45° south-east shadow at 50%
  opacity black (`#1A1410` at α≈0.5 before chroma-key pass). The shadow
  shape mirrors the building footprint, not the roof silhouette.

## Building register

Every building, walker and ship is drawn by the procedural kit in
`scripts/generate_sprites_ai/buildings.py` and `units.py`, following
these rules so new content always belongs:

- **Geometry.** Sprites are drawn in footprint space and projected onto a
  canvas exactly as wide as the footprint diamond ((w + h) × 32 px). The
  canvas bottom row is the diamond's bottom vertex. Each building stands
  on a packed-earth yard covering its whole footprint.
- **Light.** From the north-west. The south-west wall (left on screen)
  takes the material's mid-tone; the south-east wall (right) its shade.
- **Outline.** 1 px `#1A1410` on the shaded wall's outer edges, along the
  bottom of both walls and under roof eaves. The lit wall's far edge
  uses the material's shade instead.
- **Height.** 10 px per storey. Roofs overhang walls by 0.12 tiles and
  carry tile courses in the roof material's shade.
- **Materials.** Plaster `#D4A86A`/`#A07C50`, timber `#A07C50`/`#6E4A2A`,
  stone `#A89884`/`#7A6B59`, terracotta `#A53329`/`#7A1F1A`, slate
  `#7A6B59`/`#3F2A26`, thatch `#D2C094`/`#8B5A2B`.
- **Cast shadow.** A short `#3D2A1D` contact shadow along the south-east
  side, drawn opaque (sprites use binary alpha).
- **Construction.** Every building shows the same three stages: stone
  pad, timber frame, walls with scaffolding.
- **Animation.** Operational frames keep the finished building
  pixel-identical and add a rising smoke plume.

## Background

Generated sprites SHALL ship with **real PNG transparency**, not a
chroma-key colour. The pipeline calls the image API with
`background: "transparent"` (or whatever the current model's
equivalent is); the model is expected to return a PNG with per-pixel
alpha so that pixels outside the sprite silhouette are alpha=0 in
the output bytes. The post-processor thresholds soft alpha to binary
(0 or 255) before downsampling so edges stay crisp at the pixel-art
scale — no anti-aliased halos.

Spare cells in a sheet are FULLY TRANSPARENT — the model does not
paint anything in them; the alpha there is 0 throughout.

The pipeline performs no chroma-key step. Any non-magenta colour the
model emits inside the silhouette is treated as the artist's intent
and quantized to the closest palette entry. Soft-edged transparency
from the model is thresholded; hard pixel boundaries are mandatory
for the chunky pixel-art look.

## Forbidden

The following elements MUST NEVER appear in any generated sprite. The
pipeline will reject sheets that contain them after visual review.

- **Modern signifiers.** No power lines, no satellite dishes, no
  asphalt, no cars, no signage in modern Latin lettering above 4×4 px.
- **Photorealism.** No anti-aliased edges, no smooth gradients, no
  Gaussian blur, no chromatic aberration, no lens flare.
- **Anachronistic architecture.** No skyscrapers, no concrete brutalism,
  no glass curtain walls, no Art Deco friezes.
- **Off-palette colours.** Pure saturated primaries outside the declared
  palette (especially `#FF0000`, `#00FF00`, `#0000FF`, `#FFFF00`,
  `#00FFFF`, `#FF00FF`). The pipeline produces transparency via PNG
  alpha — no colour is reserved for chroma-key.
- **People/characters as detailed renders.** Walker units are stylised
  silhouettes (4–6 visible pixels tall in canonical space), never
  portraits or finely-detailed faces.
- **Weapons / military signifiers.** No swords, shields, banners with
  heraldry, archers, siege engines. The game's tone is mercantile, not
  military.
- **Text overlays.** No floating numbers, no progress bars, no UI
  chrome embedded in the sprite. Those belong to the renderer, not the
  asset.
- **Animation suggestions inside a single cell.** Smoke wisps, flag
  waves, sawblade rotations occupy separate cells in the sheet. A
  single static cell never contains motion blur or speed lines.
