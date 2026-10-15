---
name: iso-sprite-authoring
description: Author citybuilder's isometric sprites in code, without image generation. Buildings are pre-rendered 3D from the SceneKit kit (kit/), terrain is generated SVG transition tiles (terrain/), and walkers are covered too. Everything renders to PNG at true 64x32 game scale. Use when adding or fixing a building, construction stage, animated part, terrain or shore tile, or any sprite in Resources/*.atlas, or when checking that art holds up at sprite scale.
---

# Iso sprite authoring

Direction (owner, #84): **pre-rendered 3D buildings on painterly 2D terrain**.

```
cd .claude/skills/iso-sprite-authoring/kit
xcrun swiftc -o /tmp/isokit *.swift        # ~2.4 s, no Xcode project; never bare swift
/tmp/isokit <out> 1,2,3                    # 36 sprites in ~1.1 s (first render ~0.7 s Metal warm-up)
python3 -I ../terrain/transitions.py <svg-out>   # 28 transition + 9 full tiles
```

## Grid and anchors (from the code)

- Tile 64×32 (`IsoMath`, `Packages/CityRender2D`). Tile (c,r) top corner at
  `(32(c-r), 16(c+r))`; +c = screen down-right, +r = down-left.
- Building cell: n×n footprint → **64n px wide**; anchor `(0.5, 0)` =
  footprint bottom corner. Height per building:
  `px = ((4n−x)+(4n−z))·4 + y·9.8` for the tallest point (x,z,y in metres).
  The proof cells are house 112, citizen house 144, sawmill 128, town center 192.
- Textures use `.nearest`; a 1× sprite shows at about 3× on iPhone. Review at 3×.
- Walkers: 10×16 (8×12 is too small to read).

## 3D kit (kit/)

- `Kit.swift`: camera, rig, renderer. **Camera:** ortho, euler `(−30°, 45°, 0)`,
  1 tile = 4 m, `pxPerMetre = 64/(4√2) = 11.31`, `orthographicScale = H/2/pxPerMetre`,
  vertical projection, placed at `anchor + up·H/2/ppm − forward·80`.
  **Rig:** sun `(1, .84, .64)` 2600 from `centre + (−9, 30, 9)`, soft shadows
  (4096, 16 samples, radius 4), sky ambient 480, SSAO 1.4 / 0.5, HDR −0.3.
  Render at 4× and downsample with `.high`.
- `Materials.swift`: 11 finishes from seeded procedural textures (plaster,
  pale plaster, timber, rubble, ashlar, planks, thatch, tile, slate, cobbles,
  wood, plus paint and glass). Finishes mark the tier: **thatch + plaster =
  peasant; tile/slate + ashlar = citizen and civic.**
- `Parts.swift` / `Props.swift`: blocks, gable and hip roofs, timber frame,
  window (+shutters), door, chimney, porch, fence, log and plank stacks,
  barrel, crate, sapling, stump, well, market stall, ground slabs.
- `Buildings.swift`: a recipe = 19–38 lines of parts and numbers. No geometry
  code goes in recipes.

Rules learned building the first six:
- Decorate only **south (+z) and east (+x)** faces. The camera never sees the
  others.
- Roof slabs (`SCNBox`) map u down the slope: rotate the texture 90°.
  Hip-roof polygons get their own UVs (u along the eave), so no rotation.
- Thin slabs (paving, yards) show their top face: map V across it, not up its
  4 cm height, or cobbles turn into stripes.
- **Moving parts** (sails, saws) are overlay frames in the same cell. Render
  the building **depth-only** (`colorBufferWriteMask = []`, no ground) plus
  the part, so occlusion and shadows on the part stay right. Four-blade sails
  repeat every 90°, so 4 frames cover a full turn.
- **Construction stages** come from the same recipe: `stage` guards (frame →
  walls and roof boards → finished). No extra art.
- **Not byte-stable:** SSAO noise (≤32/255) and z-fighting on coplanar faces
  vary between runs. Compare renders with a tolerance, and keep coplanar parts
  ≥ 1 cm apart. `ISOKIT_SSAO=0` removes the noise but loses contact shading.

## Terrain tiles (terrain/transitions.py)

- Corner (Wang) masks N/E/S/W → 14 transition tiles per pair, plus full-tile
  variants. Pairs are grass/sand and sand/water, so the map must keep **sand
  between grass and water** (turn any water vertex next to grass into sand).
- The boundary crosses each tile edge **at its midpoint, leaving perpendicular**,
  so neighbours join. Wobble fades to zero at both ends.
- **Bleed:** exact diamonds leave 1 px stair gaps once composited. Mask
  with a diamond 1 px larger, and extend every region ~2.5 px (`BLEED = 0.08`
  uv) past the edge, or the bleed shows the wrong terrain as dotted lines.
- Pattern period must divide **32×16**. Per-tile clutter stays within uv
  0.2–0.8. Never use feTurbulence in tiles.
- Shore layers: water → shallow band (12 px blurred stroke) → faint second
  foam → sand → wet-sand inner band (clipped) → 1.4 px foam line. Grass edge:
  a 5 px blurred yellow-green fringe under the grass.
- Sandbox: shell loops over rsvg get blocked. Drive rsvg from Python.

## Checking

`examples/compose_patch.py` lays sprites on a small patch. The round-2 scratch
scripts composed whole islands from tiles plus kit sprites at 1× (nearest 2×)
and @2×. Always look at both before anything enters an atlas.

`examples/*.svg` are the round-1 hand SVG sprites (house, tiles, walker). Use
them for the pixel fallback and for icons.
