## Why

The current sprite source-of-truth is a 2105-line procedural Swift script (`scripts/generate-sprites.swift`) that hand-draws every pixel for terrain, buildings, walkers, and ships. Adding a new building means writing tens to hundreds of lines of `Pixmap` draw code; the visual ceiling is the contributor's pixel-art ability. Empirically validated in spike work (see `.scratch/ai-sprite-bakeoff/`): one `/v1/images/edits` call against OpenAI `gpt-image-2-2026-04-21` with a natural-language description plus a style-anchor reference image produces a complete 8-cell sprite sheet — base + operational animation frames + 3 construction stages — at Anno-1602/Stronghold fidelity for ~$0.04. Inter-building style cohesion is held by a single master-reference image. The pipeline collapses the per-building authoring cost from "hours of pixel-pushing" to "minutes of natural-language editing."

## What Changes

- **BREAKING** Retire `scripts/generate-sprites.swift` as the source of truth. The procedural draw helpers (`drawSawBlade(angleStep:)`, `drawSmokeOffset`, `drawFlagWave`, `drawScaffold`, `drawWaterShimmer`, all sprite functions) are removed. The script moves to `scripts/legacy/generate-sprites.swift` for one release as visual reference, then deletes.
- **BREAKING** Every PNG under `Resources/{Terrain,Buildings,Units,Icons}.atlas/` is regenerated through the new pipeline. Existing filenames and atlas locations are preserved — downstream code paths (`SpriteAtlas`, `SpriteAnimation` catalog, `IsoWorldScene` reconciler) are untouched.
- Add `Resources/Sprites.style/world.md` — natural-language style bible. Source of truth for theme, era, palette, projection, outline, shading, forbidden elements.
- Add `Resources/Sprites.style/master-reference.png` — committed binary, generated once from `world.md`, attached to every per-building call to anchor inter-building style cohesion.
- Add `Resources/Sprites.style/catalog/<id>.md` for every sprite kind currently in `Resources/*.atlas/` — natural-language per-building specification (function, visual identity, sheet layout, animation cells, notes).
- Add `scripts/generate-sprites-ai.py` (Python + Pillow + httpx) — composer + batcher + slicer + post-process. Reads `world.md` and `catalog/*.md`, fans out concurrent `/v1/images/edits` calls, slices returned sheets into per-cell PNGs, chroma-keys the magenta background, downsamples + quantizes to the canonical palette, writes into the correct `*.atlas/` directories.
- Add `make sprites` target — hermetic regeneration from the catalog. With cache hits it's a no-op; with cache misses it requires `OPENAI_API_KEY` and a network connection.
- Add prompt-hash caching under `Resources/Sprites.style/_cache/` (gitignored). Cache key is `sha256(world.md + catalog/<id>.md + fixed_instructions + model_id)`. Re-runs are idempotent when inputs are unchanged.
- Policy: **single-pass `/edits` with master-reference is the default**. A two-pass escape hatch (regenerate animation frames against a pass-1 cell as reference) is documented for any building where playtest reveals visible flicker.
- Update README "Adding a new animated sprite" and "Adding a new good icon" sections to point at the catalog workflow.

## Capabilities

### New Capabilities
- `sprite-style-catalog`: the natural-language style bible + per-sprite catalog + AI generation pipeline + caching contract. Defines how PNGs are produced. Independent of where they live and how they're named (that stays in `sprite-asset-pipeline`).

### Modified Capabilities
- `sprite-asset-pipeline`: layered with three new requirements describing source-of-truth for PNG contents (catalog-driven, not procedural), retirement of the procedural generator, and hermetic regeneration via `make sprites`. Existing requirements (atlas layout, naming grammar, atlas routing, presence validation, variant slots) are unchanged.

## Impact

- **New build-time dependency**: Python 3.11+ with `Pillow>=10` and `httpx>=0.27`. Installed via a project-local `scripts/requirements.txt` and a `make sprites-venv` target that creates `.venv/sprites/`. README onboarding gains one step: `make sprites-venv` after `make hooks`. No runtime dependency change — generated PNGs remain plain bundle resources.
- **New external service dependency at sprite-regen time**: OpenAI Images API (`/v1/images/edits`). Contributors regenerating sprites need `OPENAI_API_KEY` in their environment. CI does NOT regenerate sprites — it verifies the committed PNGs match the catalog by replaying the prompt-hash cache. Cache misses in CI fail the build.
- **Repo size**: master-reference.png (~1 MB) and the regenerated atlas PNGs are committed. Existing atlas footprint is replaced, not added to. Net change expected within ±2 MB.
- **Code removed**: `scripts/generate-sprites.swift` (2105 lines) deleted after one transition release.
- **Code unchanged**: `Packages/CityRender2D/Sources/CityRender2D/SpriteAnimation.swift`, `Packages/CityRender2D/Sources/CityRender2D/SpriteAtlas.swift`, `IsoWorldScene`, all renderer code paths. The pipeline only writes to the same atlas directories with the same filenames.
- **Visual ceiling lift**: post-archive, every sprite is at the AI pipeline's fidelity tier (higher detail than the current procedural blocks). The README "Adding a new animated sprite" workflow becomes catalog-driven authoring rather than Swift draw code.
- **Save-format compatibility**: unaffected. Sprites are visual-only assets; the simulation core never references them.
