## Why

The game has no single visual style. Terrain, roads and the farm are procedural pixel art built from strict iso geometry. Every other building, plus walkers and ships, is an AI drawing in a looser, painterly register, with its own perspective, sizing and outline habits. Placed next to each other they read as two different games. The game direction (see `openspec/explorations/game-direction-pile.md`) adds four cultures across five ages, so dozens of new buildings are coming. They need one register to belong to before they're drawn.

## What Changes

- **Building register in the style bible.** `world.md` gets a section that pins the rules every building follows: footprint-exact iso geometry, wall height per tile, light from the north-west (lit south-west wall, shaded south-east wall), 1-px `#1A1410` outline on the shaded side and bottom, palette roles per material, and a south-east cast shadow.
- **Procedural building kit.** `procedural.py` gains reusable iso primitives (walls, gable roofs, hip roofs, timber framing, windows, doors, chimneys, piers, crenellations) that draw onto a canvas sized exactly to the footprint.
- **Redraw every building** in that kit: house, warehouse, lumberjack hut, sawmill, town center, and port and shipyard in all four orientations. Each gets three construction stages (stone pad → timber frame → walls with scaffolding). Operational frames stay derived from the finished sprite (a smoke plume).
- **Redraw walkers and ships** in the same register, so every sprite in the world comes from one renderer. Goods icons stay as they are: they're HUD art, not world art.
- **Content gate:** every building base sprite must use the outline colour, and its opaque pixels must reach the bottom vertex of its footprint diamond. This catches sprites that float or drift out of the style.
- **Renderer anchor fix:** building sprites anchor at their footprint's bottom vertex. The old offset only matched square footprints, so 2×3 shore buildings hung 16 px below their tiles.
- **Sizing:** sprite canvases now match their footprint diamond (2×3 shore buildings become 160 px wide instead of 128) so nothing is squeezed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `sprite-style-catalog`: every building and unit catalog entry is drawn procedurally; the style bible pins the building register.
- `rendering-2_5d`: building sprites anchor at the footprint's bottom vertex for every footprint shape.
- `sprite-asset-pipeline`: the content gate checks outline use and footprint grounding for building sprites; procedural sprites set their own canvas size.

## Impact

- **Art:** all building PNGs (13 kinds, about 75 files) plus 24 walker and ship frames are regenerated locally with `make sprites-procedural`. No API key is needed.
- **Pipeline (Python):** `procedural.py` grows a building kit. The batcher takes procedural canvas sizes from the renderer instead of from the committed PNG.
- **CityRender2D:** the building and ghost sprite anchor uses `w + h − 1` half-tiles instead of `2h − 1`. The gate (`SpriteContentGate`) gains two rules.
- **CityCore, CityUI, CityPersistence:** no change.
- **Build tools:** none new.
