## Context

Today `make sprites` runs `scripts/generate_sprites_ai`:

- A PIL "procedural" register draws 96 sheets into `Resources/Sprites.style/_sheets/`.
- The OpenAI image API draws 3 goods icons.
- The sheets are sliced into the atlases.
- `make sprites-verify` checks byte-identical regeneration plus the Swift content gate.

The renderer draws one 64×32 texture per tile from its `TerrainKind` and places building sprites bottom-centre on the footprint's bottom vertex. Every texture uses `.nearest` filtering.

Rounds 1 and 2a of #84 (the "Citybuilder art direction" canvas) compared pixel, vector, painterly, diorama and pre-rendered 3D looks. The owner chose pre-rendered 3D buildings on painterly terrain. The Kit proof produced:

- six buildings, two construction stages and four sail frames, in 1.1 s
- 28 transition tiles
- an island built only from tiles and kit sprites

The prototype lives in `.claude/skills/iso-sprite-authoring/kit/` and `terrain/`.

## Goals / Non-Goals

**Goals:**
- One source-controlled, Claude-authored pipeline for every terrain, building and unit sprite, with no image generation and no network.
- Consistency across 40+ building kinds through one camera, one light rig and one finish set.
- Shorelines and grass edges that blend.
- Higher-fidelity art that still renders crisply on iPhone, iPad, Mac and Apple TV.
- Rollout in small, reviewable PRs, one asset family at a time, each with in-game evidence.

**Non-Goals:**
- Real-time 3D in the game. SceneKit is used only offline to render PNGs.
- Forest and mountain transitions, rivers and roads-as-terrain. Each gets its own later change.
- Time-of-day relighting. Night stays the existing overlay.
- New gameplay, or any change to `CityCore`.

## Decisions

### D1. Kit as a SwiftPM tool package, built with `xcrun swift`

`Tools/IsoKit` is an executable package (`isokit`). It has the modules `Kit` (camera, rig, renderer), `Finishes`, `Parts`, `Props`, `Recipes` and a CLI. `make sprites` runs `xcrun swift run -c release --package-path Tools/IsoKit isokit render Resources`. Not wiring it into the Xcode project keeps app builds untouched, and the prototype compiled in 2.4 s with `swiftc`.

*Alternatives:*
- Blender: needs a heavy external install and Python scene code, outside Claude's Swift-native strength.
- RealityKit: offline rendering is less mature than `SCNRenderer.snapshot`.
- A script run with `xcrun swift file.swift`: no multi-file modules.

### D2. Fixed 2:1 camera and cell geometry

The camera is orthographic, with euler angles (−30°, 45°, 0) and vertical projection. One tile is 4 m, so `pxPerMetre = 64 / (4√2)`. A cell for an n×n footprint is 64n points wide. Its height is declared per recipe, with the footprint's bottom vertex at bottom-centre, which matches `rendering-2_5d` "Building sprites anchor at the footprint's bottom vertex". Each recipe declares its cell height. A unit test computes the tallest point of each recipe and fails if it would be clipped.

### D3. One light rig and finish set; tiers through finishes

The rig and finish values follow the prototype:

- **Sun:** (1.0, 0.84, 0.64) at 2600, from upper screen-left and high enough to keep the cast shadow inside the cell.
- **Shadows:** 4096-pixel map, 16 samples, radius 4.
- **Sky fill:** 480 ambient.
- **Camera:** SSAO and HDR.
- **Finishes:** 11 procedural, seeded-texture PBR finishes. Thatch and plaster mark the peasant tier; tile, slate and ashlar mark the citizen and civic tiers.

Recipes may not create lights or materials outside the finish set. This is the consistency guarantee across 40+ buildings.

### D4. Construction stages and moving parts come from the recipe

- `constructing-0…2` render the same recipe at three stages: plinth and bare frame, walls and roof boards, then a near-finished stage with scaffold.
- Operational frames come from moving parts: sails, saw, water wheel, bellows. Each part renders as an overlay frame with the building drawn depth-only and no ground. That keeps occlusion and shadows on the part correct. The tool then composites base + overlay into `building-<kind>-operational-<n>`.

The atlas names and `sprite-animation` rules are unchanged, so the renderer needs no animation change. Smoke stays SpriteKit particles.

### D5. Tolerance regen check, not byte identity

Two runs of the same input measured:

- **SSAO on:** worst mean absolute difference 0.002/255; 0.014% of pixels differ by more than 8; peak 32.
- **Without SSAO:** a few pixels still flip because coplanar faces z-fight.

The committed PNGs are 256-colour indexed (D8), and quantization turns out to dominate. libimagequant picks slightly different palettes for near-identical inputs, so comparing two quantized renders fails on 24 of 62 Kit-proof PNGs. Comparing a fresh raw render with its own quantized PNG shows quantization error alone: worst mean 0.69/255, with 0.06% of pixels off by more than 24. Raw render A against quantized render B gives the same numbers, so GPU noise is negligible next to it.

`make sprites-verify` therefore renders to a scratch directory and compares each fresh **raw** render with its committed indexed PNG. Both are premultiplied, so fully transparent pixels compare equal whatever RGB the palette's transparent entry carries. A PNG fails when the mean absolute difference exceeds 1.5/255, or when more than 0.3% of pixels differ by more than 24, which is about twice and five times the measured worst cases. A real change such as a roof finish swap is off by tens of units over whole faces and fails clearly.

Coplanar parts must sit at least 1 cm apart. An `ISOKIT_SSAO=0` switch exists for debugging.

### D6. Terrain transitions by corner masks

Each map vertex takes a terrain from its four adjacent tiles, with forest and mountain counting as grass:

- If the tiles include both grass and water, the vertex is **beach**.
- Otherwise it takes the lowest-ranked terrain present (water < beach < grass).

A tile's own kind is always among its corners' neighbours, so a grass tile never gets a water corner and a water tile never gets a grass corner. At a direct grass–water edge, the two shared vertices become beach. The grass tile then draws a grass→beach transition, and the water tile draws a beach→water one, so beach always separates grass from water with no per-tile fix-up.

A tile whose corners mix two terrains draws `terrain-<upper>-<lower>-t<mask>`. The mask bits are N=1, E=2, S=4, W=8, and a set bit means "upper". Uniform tiles keep their existing names and variants.

Generator rules:
- Every boundary curve crosses a tile edge at its midpoint, perpendicular to the edge, so neighbours join.
- Tiles bleed 1 point past the diamond. Exact diamonds leave stair gaps, and linear filtering would sample transparent texels.
- Each region extends past the edge so the bleed shows the correct terrain.
- Texture period is 32×16 so patterns line up across tiles.

The generator stays Python + rsvg in the existing sprites venv. Its SVG sources are what Claude reads and edits.

### D7. @2× atlases with linear filtering

**Recommendation: ship @2× textures and switch terrain, building and unit textures to `.linear`.** Icons stay `.nearest`.

- The renders are anti-aliased images, not pixel art. With `.nearest` at the iPhone's ~3× point scale they show stair-stepped soft edges. @2× with linear filtering stays crisp at today's zoom range.
- @3× was not worth it: GPU memory triples for a difference only visible at maximum zoom on iPhone.
- @1× with linear filtering alone looked soft on retina.

The 1-point tile bleed (2 px @2×) keeps linear sampling inside opaque texels at tile edges.

SpriteKit picks `@2x` atlas images on retina devices automatically. Sprite sizes stay in points, so `IsoMath` and the anchors do not change.

**Kit renders get their own atlas.** SpriteKit applies one filtering mode to a whole atlas page: when a page mixes `.linear` and `.nearest` sub-textures, every texture on it uses whichever mode was set last. This was measured with the house render and a legacy building on one page. So art-kit renders live in `Resources/Kit.atlas`, which is linear, and the pixel art still in `Buildings` and `Units` stays `.nearest`. Routing sends a sprite to `Kit` when its brief has migrated; each family PR moves its files there, and an atlas whose last sprite migrates is removed (`Terrain` went with the terrain family). Once every family has migrated, the legacy atlases hold only the `.nearest` goods icons and status badges. Because no atlas mixes kit and legacy art, legacy sprites need no nearest-neighbour `@2x` twins: SpriteKit only skips 1x-only sprites in an atlas that also has `@2x` art.

### D8. Indexed 256-colour PNGs stay

Pillow FASTOCTREE quantization of a 3D render @2× was 5.4× smaller than RGBA (15 KB vs 84 KB) with no visible difference. The 256-colour indexed rule of `sprite-asset-pipeline` therefore stays. The render tool quantizes on write.

### D9. Walkers move to their own change

The 8×12 walker cannot show a hat, a load or a gait. The plan here was a 10×16 kit figure with 4 gait frames; `realistic-walkers` supersedes it with storybook-scale people (24×30 points, 8 gait frames), carrier looks per good family and animals. Ships moved to the kit in the shore family PR.

### D10. Catalog entries become briefs

`Resources/Sprites.style/catalog/<id>.md` keeps `Function` and `Visual identity`. It replaces `Sheet` and `Animation` with a `Recipe` section that names the IsoKit recipe, cell height, stages and moving part. A test keeps catalog entries and recipes one-to-one. `world.md` becomes the kit's style bible.

## Risks / Trade-offs

- **[GPU-dependent renders]** Output differs slightly across GPUs and OS versions. → Tolerance check (D5). Committed PNGs are the source of truth for builds, and only `make sprites-verify` re-renders.
- **[CI has no reliable Metal]** → The regen check runs locally and in the family PRs' test plans. CI keeps the content gate, which needs no GPU.
- **[Atlas size and memory doubles with @2×]** → Indexed PNGs (D8), and atlas memory is checked on Apple TV in the houses-family PR. Falling back to @1× + linear for terrain only is the escape hatch.
- **[Mixed looks during rollout]** Old procedural and new kit sprites coexist for a few PRs. → Families are chosen so related buildings flip together (all houses, then forestry, …), and each PR shows before/after.
- **[Map generation puts grass next to water]** → D6 makes the shared vertices beach visually. The simulation still sees the tile's own kind.
- **[Linear filtering blurs icons and overlays]** → Icons and status badges keep `.nearest`, and the rendering spec states which textures are linear.

## Migration Plan

1. Land `Tools/IsoKit`, the terrain generator and the new verification behind the existing atlases. Nothing visible changes.
2. Flip atlases family by family (tasks §4). Each PR regenerates only that family's PNGs, includes a before/after in-game screenshot, and passes the content gate and the tolerance check.
3. After the last family:
   - delete `scripts/generate_sprites_ai/`, `_sheets/`, `master-reference.png` and the model pin
   - remove the `sprites-reference`, `sprites-procedural` and `sprites-offline` targets
   - rewrite the README sprite section
   - archive the change

**Rollback:** any family PR reverts cleanly, because PNG names and the renderer contract are unchanged. The renderer change (D6/D7) lands with the terrain family and can be reverted with it.

## Open Questions

- Do status overlay badges move to the kit (3D signage) or stay pixel art? Proposed: they stay pixel art in this change.
- Shore buildings (port, shipyard) need four orientations. Resolved in the ships and shore family PR: a facing moves the geometry (shore buildings lay out in a land-to-sea frame, ships turn about their centre), so the camera and the light rig stay fixed in screen space and every facing lights alike.
