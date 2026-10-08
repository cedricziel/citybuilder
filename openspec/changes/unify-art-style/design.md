## Context

See proposal.md (Why). Facts that shape the approach:

- **Procedural renderer.** `scripts/generate_sprites_ai/procedural.py` already draws terrain, roads and the farm at canonical size. `render_sheet` upscales the result, and the offline pipeline downsamples it back byte-exactly.
- **Canvas sizes.** The batcher takes each sprite's target size from the committed PNG, falling back to a per-prefix default. Procedural sprites need their own size, because buildings now get footprint-exact canvases.
- **Placement.** The renderer places a building sprite with anchor (0.5, 0) at an offset from the anchor tile. The y offset used `2h − 1` half-tiles, which only matches the footprint's bottom vertex when w = h.
- **Sizes today.** House, lumberjack and sawmill are 128 wide; town center and warehouse are 192; ports and shipyards are 128 wide despite their 160-px diamond.

## Goals / Non-Goals

**Goals:**
- One register for every world sprite: terrain, roads, buildings, walkers, ships.
- A small kit, so a new building is a few lines of composition rather than hand-tuned polygons.
- Sprites that sit exactly on their tiles for every footprint shape.

**Non-Goals:**
- Goods icons (HUD art).
- Per-age or per-culture variants: the kit is built so they can come later (`add-cultures`, `add-historical-ages`), but none ship here.
- New animation beyond the derived smoke plume.

## Decisions

### D1 — An iso projection helper maps footprint space to canvas pixels

A `Projector(w, h, canvas)` maps footprint-local coordinates (u along +x tiles, v along +y tiles, z height in pixels) to canvas pixels:

- x = cx₀ + (u − v) · 32
- y = cy₀ + (u + v) · 16 − z

cx₀ centres the diamond horizontally and cy₀ puts the bottom vertex (u = w, v = h) on the canvas's last row. Every primitive (box, roof, pier, opening) is defined in footprint space, so buildings compose without pixel bookkeeping, and any footprint shape works.

- **Alternative — keep hand-placed polygons per building, like the first farm.** Rejected. The farm's barn needed per-pixel tuning, and repeating that for 13 kinds × 4 stages across five ages doesn't scale.

### D2 — The register rules

Pinned in `world.md` § Building register and enforced by the kit:

- **Light** from the north-west: the south-west wall (the left face on screen) takes the material's mid-tone, and the south-east wall (right face) its shadow tone.
- **Outline:** a 1-px `#1A1410` outline on the right face's outer edges and along the bottom edges of both walls. Roof eaves get the same.
- **Wall height:** 10 px per storey; roofs rise 0.5 × the short footprint side in tiles × 16 px.
- **Cast shadow:** a `#1A1410` parallelogram to the south-east, offset 6 px. It's drawn opaque, because sprites have binary alpha, and kept small so it reads as a contact shadow.
- **Materials** map to palette roles: plaster `#D4A86A`/`#A07C50`, timber `#6E4A2A`/`#4A2F1A`, stone `#A89884`/`#7A6B59`, terracotta `#A53329`/`#7A1F1A`, slate `#7A6B59`/`#3F2A26`, thatch `#C9A671`/`#8B5A2B`.

### D3 — Construction stages are a property of the kit

Every building is described once as a list of parts (walls, roof, details). The stage parameter renders a subset:

- `pad`: stone foundation on the footprint.
- `frame`: corner posts and a top ring beam.
- `walls`: walls plus scaffolding poles, no roof.
- `done`: everything.

So construction frames are automatically consistent with the finished building.

### D4 — Procedural sprites own their canvas size

`procedural.size(name)` returns the canvas size, and the batcher's `_target_size` prefers it over the committed PNG for procedural entries. `render_sheet` upscales by an integer factor (8×) instead of forcing a 1024² square, so non-square canvases round-trip exactly.

- **Alternative — keep the old sizes and squeeze.** Rejected. The 2×3 diamond is 160 px wide and doesn't fit in 128.

### D5 — Fix the anchor offset in the renderer

`buildingSpriteNode` and the ghost use `offsetY = −halfH · (w + h − 1)`, which is the footprint's bottom vertex. For square footprints this equals the old `2h − 1`, so houses, mills and the town center don't move. Ports and shipyards move up 16 px onto their tiles.

## Determinism

The renderer change is visual only; no simulation state is touched. Sprites are drawn from integer geometry and a fixed hash, so `make sprites-verify` stays byte-identical.

## Risks / Trade-offs

- **[Risk] Simple geometry reads as plain next to the old painterly buildings** → Mitigation: every building is redrawn at once, so there is no mix. Detail comes from windows, timber framing, chimneys and props, which the kit makes cheap.
- **[Risk] Larger shore-building canvases shift their on-screen footprint** → Mitigation: D5 anchors on the true vertex, and the content gate checks grounding.
- **[Trade-off] The cast shadow is opaque.** With binary alpha a 50% shadow isn't possible, so it stays a thin contact shadow.
