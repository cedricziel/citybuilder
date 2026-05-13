## Context

The current sprite pipeline is `scripts/generate-sprites.swift` — a 2105-line Swift program that draws every pixel of every terrain tile, building, walker, and ship into a `Pixmap`, then emits PNGs into `Resources/{Terrain,Buildings,Units}.atlas/`. Adding a building means writing tens to hundreds of lines of `Pixmap` draw code; iteration is slow and the visual ceiling is bounded by hand-drawn pixel-art ability.

A spike in `.scratch/ai-sprite-bakeoff/` (committed only as scratch, not part of the repo proper) validated four hypotheses against OpenAI `gpt-image-2-2026-04-21`:

1. **Style adherence via reference image.** `/v1/images/edits` with a procedural-house PNG attached as reference produced a higher-fidelity sprite that held the existing palette, outline weight, and pixel scale almost exactly. Mean RGB diff from the reference was ~2/255 per channel; sig-pixel-diff was 2.3%. The model can be anchored.
2. **Multi-cell sheet generation in one call.** A 3-cell horizontal strip held the building body pixel-identical across cells (97.6% coherence) while varying only the smoke wisp. Animation frames can be batched.
3. **Pure-generation can originate designs.** A windmill prompt with no reference produced an original Anno-tier design with three coherent construction stages and rotating sails. The first attempt drifted ("two windmills" — flat cap vs conical cap across row 0); explicit identity-coherence prompt language ("do not invent variations of the building") cut design drift in half on a sawmill retry.
4. **Sub-pixel surface jitter is endemic to pure generation.** Even with identity-locked design, ~24% of pixels differ between distant cells in a sheet. Adjacent cells are ~2.5× more coherent (10% vs 24%). At downsampled sprite resolution this reads as natural variation; for buildings where playtest reveals visible flicker, a two-pass workflow (pure-gen design → `/edits` from base cell for animation frames) locks pixel coherence to ~2% sig-diff.

The contract this design must satisfy:

- Replace the procedural generator entirely. No hybrid procedural+AI per-sprite.
- Preserve the `sprite-asset-pipeline` output contract — filenames, atlas locations, presence validation, variant slots.
- Make adding a new sprite a natural-language editing task, not a Swift coding task.
- Be hermetic in CI — committed PNGs must be regenerable offline from committed catalog + committed cache.
- Stay deterministic-enough for `SpriteAtlas` debug presence validation to pass byte-identically across machines.

## Goals / Non-Goals

**Goals:**
- Single natural-language source of truth: `Resources/Sprites.style/world.md` defines the world's visual identity; `catalog/<id>.md` defines per-sprite specification.
- One API call per building produces the entire asset set (base + operational animation + 3 construction stages) when single-pass mode applies.
- Inter-building style cohesion enforced by a committed `master-reference.png` anchor.
- Idempotent regeneration: `make sprites` with unchanged inputs performs zero API calls and reproduces every committed PNG byte-for-byte.
- CI guarantees that committed PNGs always have their generating inputs (catalog + cache) committed alongside them, with no network access required to verify.
- Per-sprite opt-in escape hatch (two-pass mode) for buildings where playtest reveals animation flicker.

**Non-Goals:**
- Reverse-engineering each existing procedural sprite to bit-match it. The catalog declares the *intent* of each sprite (function, identity, sheet layout); the AI pipeline produces fresh art at the new fidelity tier. We accept that buildings look different post-archive.
- Hot-reload or in-game preview of catalog edits. Editing the catalog requires a `make sprites` run plus an Xcode rebuild.
- Running the AI pipeline at app runtime. PNGs ship in the bundle as today; the simulation never touches the network.
- Procedural code helpers (`drawSawBlade`, `drawSmokeOffset`, etc.) used as overlays composited at runtime. Animation is fully in the generated sheets.
- Goods-icon hot-fixing without a regen. Even tiny icons go through the pipeline; the catalog uses smaller cell sizes for them but the same workflow.

## Decisions

### D1: Python + Pillow + httpx for the pipeline runner, not Swift

**Decision.** Implement `scripts/generate-sprites-ai.py` in Python 3.11+, with `Pillow>=10` for image post-processing and `httpx>=0.27` for the OpenAI API. Install via a project-local virtual environment created by `make sprites-venv` from a pinned `scripts/requirements.txt`.

**Alternatives considered.**
- *Swift CLI binary (`SwiftPM` target).* Keeps the toolchain identical to the rest of the project; no new build-time dep. But: PNG palette quantization and Floyd–Steinberg dithering at this quality level are several hundred lines in Swift versus calling `Pillow.Image.quantize()` in two lines. Image post-processing is Python's home turf. The pipeline is contributor-facing tooling, not shipping app code; the Swift purity argument is weaker here than for `Packages/`.
- *Node + sharp.* Faster than Pillow for some operations but introduces a second runtime ecosystem; team already has zero Node tooling.
- *Pure shell + `sips` + `magick`.* Already showed in the spike that `sips`' in-place mutation is a footgun. Magick adds a Homebrew dep heavier than Python.

**Why.** Lowest total complexity per line of pipeline code, given image post-processing is the dominant work. The `scripts/` directory is already understood to host any-language tooling.

### D2: `/v1/images/edits` with master-reference is the default, not `/v1/images/generations`

**Decision.** Every per-sprite call uses the `/v1/images/edits` endpoint with `image=master-reference.png` attached. Pure `/v1/images/generations` is reserved for the one-time generation of `master-reference.png` itself.

**Alternatives considered.**
- *Pure `/generations` for every sprite.* The windmill spike showed design drift within a single sheet (two windmills). Without an anchor, drift compounds across sprites; the bakery and the church would not look like they share a city. Sprite-style coherence is the core thing that distinguishes a game world from a moodboard.
- *`/edits` with the most-recently-generated AI sprite as anchor.* Error compounds: each generation drifts slightly from its anchor, and using its output as the next anchor amplifies the drift. Always use the committed `master-reference.png`, never an AI-produced sprite as input.

**Why.** Inter-sprite cohesion is a global property; it needs a global anchor. The cost is one extra `multipart/form-data` field per call.

### D3: Magenta `#FF00FF` chroma-key as the transparent-background convention

**Decision.** All prompts instruct the model to fill empty space with solid magenta `#FF00FF`. Post-process step converts magenta to alpha=0.

**Alternatives considered.**
- *Ask the model for transparent PNG directly.* `gpt-image-2` supports a `background: "transparent"` parameter, but in spike testing it produced soft-edged alpha that didn't survive the downsample-to-pixel-art pass. Hard-edged chroma-key produces crisp pixel-perfect alpha.
- *Use a different chroma colour (green, blue).* Magenta is the legacy chroma-key in video for a reason: it's almost never used in natural imagery (and explicitly not in our palette of warm browns, terracottas, stone-greys), so false-positive pixels are rare.

**Why.** Sharp pixel-perfect alpha boundaries are mandatory for the chunky pixel-art aesthetic.

### D4: Pinned dated model snapshot, not a floating alias

**Decision.** `Resources/Sprites.style/pipeline.toml` declares `model = "gpt-image-2-2026-04-21"`. Floating aliases (`gpt-image-2`, `gpt-image-latest`, etc.) MUST NOT be used.

**Alternatives considered.**
- *Floating alias.* Auto-tracks model improvements but breaks reproducibility — running `make sprites` six months later would produce different bytes than what was committed, even with no catalog edits. Defeats the hermetic-regen guarantee.

**Why.** Reproducibility outranks chasing model improvements. Model bumps are explicit `pipeline.toml` edits, treated like any other versioned change.

### D5: Prompt-hash cache as the bridge between catalog and committed PNGs

**Decision.** Cache key = `sha256(world.md_content || catalog/<id>.md_content || fixed_instructions_string || model_id_string)`. Cache stored under `Resources/Sprites.style/_cache/<hash>.png` and `_cache/<hash>.json` (raw API response, for re-slicing without re-billing). The `_cache/` directory is gitignored.

**Wait — gitignored, but CI must reproduce committed PNGs offline. How?**

The committed PNGs under `Resources/*.atlas/` are the authoritative artifact. The cache is a local-developer convenience to avoid re-billing. CI does NOT replay the cache — it verifies that the catalog inputs, when sliced from the *committed* cache PNGs, produce byte-identical `Resources/*.atlas/` PNGs. The cache PNGs themselves get a parallel committed location: `Resources/Sprites.style/_sheets/<id>.png` (NOT gitignored). The hash is then a derivation artifact computed for the cache-hit shortcut on dev machines.

**Refined.** Two locations:
- `Resources/Sprites.style/_cache/<hash>.{png,json}` — gitignored, dev convenience
- `Resources/Sprites.style/_sheets/<id>.png` — COMMITTED, the authoritative source-of-truth pre-slice. `make sprites --offline` reads from here.

**Alternatives considered.**
- *Commit only the post-sliced atlas PNGs.* CI can't re-derive them without an API call; loses determinism. Rejected.
- *Commit only the raw sheets, slice at runtime.* Doesn't match the existing `sprite-asset-pipeline` contract that says PNGs live at specific atlas paths. Rejected.

**Why.** Committed `_sheets/` give CI offline reproducibility; the `_cache/` directory speeds up dev iteration.

### D6: Animation frames must be adjacent cells in the sheet

**Decision.** The catalog entry's `Sheet` section MUST place animation-loop cells in adjacent grid positions (same row, neighbouring columns, or same column, neighbouring rows). Tested at catalog-parse time.

**Why.** The spike measured 10% sig-pixel diff for adjacent cells vs 24% for distant cells — a 2.5× coherence advantage that the model picks up from spatial proximity in the canvas. Distant placement compounds animation flicker. This is a fast-win constraint contributors can satisfy without thinking.

### D7: Two-pass coherence is opt-in per catalog entry, not the default

**Decision.** Default mode is single-pass `/edits`. A catalog entry opts in via a YAML front-matter `two-pass: true`. In two-pass mode the pipeline runs:
- pass-1: `/v1/images/edits` with master-reference, producing base + construction-stage cells; operational cells left as solid magenta.
- pass-2: `/v1/images/edits` with the pass-1 base cell as reference, producing only operational animation frames.

**Alternatives considered.**
- *Two-pass for everything.* Doubles API cost ($0.08 vs $0.04 per building) and wall-clock time. The 24% jitter is invisible at downsampled scale for most buildings; the spike confirmed it reads as "alive" rather than "broken." Two-pass should be reserved for buildings that fail playtest.
- *Two-pass for animation-heavy buildings only (auto-detected by frame count).* Auto-detection conflates a structural property (frame count) with a perceptual one (flicker visibility). A 2-frame animation might flicker; an 8-frame one might not. Manual opt-in trusts the contributor's eye.

**Why.** Cost discipline + perceptual judgment can't be automated. Opt-in puts the call in the right place.

### D8: Catalog format is Markdown with optional YAML front matter, not pure YAML/TOML

**Decision.** Each `catalog/<id>.md` is a Markdown file with optional YAML front matter for machine-readable flags (`two-pass`, `cell_size`, etc.) and Markdown sections for human-readable spec. Required Markdown sections: `Function`, `Visual identity`, `Sheet`, `Animation`.

**Alternatives considered.**
- *Pure YAML.* Cleaner for parsers but contributor-hostile — every visual-identity description becomes a multi-line scalar with quoting concerns. The 80% of catalog content is prose; prose belongs in Markdown.
- *Pure prose without front matter.* Forces machine-readable flags (two-pass, cell sizes) into prose parsing. Brittle.

**Why.** Markdown + front matter is the standard hybrid pattern for human-and-machine-readable specs and is already the convention OpenSpec uses for proposals and tasks.

### D9: Pipeline composer is independent of API caller is independent of slicer

**Decision.** Three pure-function modules:
- `composer.py`: `(world.md_text, entry.md_text, fixed_instructions) -> Prompt` — pure string assembly.
- `slicer.py`: `(sheet_image, catalog_entry) -> [(atlas_filename, image)]` — pure image splitting per the catalog's `Sheet` section.
- `postprocess.py`: `image -> image` — chroma-key + downsample + quantize + outline-preserve.

Only the orchestrator (`batcher.py`) makes network calls.

**Alternatives considered.**
- *One mega-script.* Faster to write; harder to test. Composer logic and slicer logic both have failure modes worth unit-testing independently of any API call.

**Why.** Pure functions are testable with golden-file fixtures. The orchestrator's network call is the only impure boundary and is mocked in tests.

### D10: Determinism of the pipeline (clarification for CityCore invariant)

The simulation core invariant — "two simulations with identical inputs produce equal `World` values" — is unaffected. Sprite PNGs are visual-only assets; the simulation core never references them. The pipeline's own determinism property is *separate*: identical (`world.md`, `catalog/`, `pipeline.toml`, `_sheets/`) MUST produce byte-identical `Resources/*.atlas/*.png`. The slicer and post-processor are pure functions; the only non-deterministic boundary is the API call, which is gated behind the cache and committed `_sheets/`.

## Risks / Trade-offs

[**Risk:** OpenAI deprecates `gpt-image-2-2026-04-21`.] → **Mitigation:** the model id is in one place (`pipeline.toml`); bumping is one commit. Cache invalidates; sheets regenerate; visual delta reviewed in PR.

[**Risk:** The new sprites look meaningfully different from the current procedural sprites, breaking established player expectation for early adopters.] → **Mitigation:** acknowledged as an intentional fidelity-tier lift. The transition is one commit; no save-format compat issue; this is a visual upgrade not a regression. The `master-reference.png` is curated to keep the medieval-coastal-town palette and silhouette register continuous with the current art.

[**Risk:** A catalog edit changes the cache key but the contributor forgets to commit the new `_sheets/<id>.png`, breaking CI.] → **Mitigation:** `make sprites` after a catalog edit writes both `_cache/` and `_sheets/`. A pre-commit hook checks that `git diff --name-only` between `Resources/Sprites.style/catalog/` and `Resources/Sprites.style/_sheets/` are consistent — editing one without the other fails the pre-commit check with a message naming the missing sheet.

[**Risk:** Goods icons at 24×24 native size lose too much detail through the downsample.] → **Mitigation:** goods icons get their own cell size (smaller grid, e.g., 6 cells of 256×256 each on a 1536×512 canvas), and the post-process uses a different downsample path (no anti-alias, pure nearest-neighbour) to preserve crispness. Tested on `good-wood` and `good-planks` before the full migration commits.

[**Risk:** The model produces images with sub-pixel building drift visible to careful eyes even after single-pass coherence prompts.] → **Mitigation:** documented two-pass escape hatch (D7). Playtest pass before the full migration commits flags which buildings need it.

[**Risk:** Catalog drift over time — `world.md` and `catalog/*.md` diverging from what the actual atlas PNGs look like.] → **Mitigation:** the hermetic-regen requirement (`make sprites --offline` reproduces committed PNGs) gates this in CI. If catalog and PNGs diverge, CI fails. The catalog is the source-of-truth by construction.

[**Risk:** Python virtual env bitrot on contributor machines.] → **Mitigation:** `scripts/requirements.txt` pins exact versions; `make sprites-venv` rebuilds from scratch; the venv lives under `.venv/sprites/` which is gitignored. README onboarding lists it as a one-time setup step.

## Migration Plan

The migration is a single coordinated change but lands in dependency-ordered commits:

1. Author `Resources/Sprites.style/world.md` (no behaviour change, file-only commit).
2. Author every `Resources/Sprites.style/catalog/<id>.md` (file-only commit per cluster: terrain, land-only buildings, shore buildings, walker, ship, goods icons).
3. Land `scripts/generate-sprites-ai.py` + `scripts/requirements.txt` + `make sprites-venv` (tooling-only commit; no atlas changes).
4. Generate and commit `Resources/Sprites.style/master-reference.png` (one-time, reviewed visually in PR).
5. Land `make sprites` and `make sprites --offline` (Makefile-only commit; depends on step 3).
6. Run full regen, commit `Resources/Sprites.style/_sheets/*.png` and the new `Resources/{Terrain,Buildings,Units,Icons}.atlas/*.png` (one large commit; reviewed visually). At this point the new pipeline produces the committed art.
7. Quarantine `scripts/generate-sprites.swift` → `scripts/legacy/generate-sprites.swift`; remove all `Makefile`/README references (deletion + docs commit).
8. After one release where the new art is in-game, delete `scripts/legacy/generate-sprites.swift` (follow-up change).

**Rollback strategy.** Steps 1–5 are additive and harmless if reverted in isolation. Step 6 is the cutover; revert by `git revert` of that commit and step 7. The simulation core and renderer code paths are never touched, so save-game compatibility is preserved at every step.

## Open Questions

- **Q1.** Does `master-reference.png` depict one canonical building (a house, the simplest test case) or a composition of three (house + sawmill + port to anchor multiple style registers)? Spike data is single-building; the multi-building variant is untested. ~~**Decision deferred to step 4 of the migration:** generate both and visually compare; commit the one that produces better inter-sprite coherence on a sample 5-building regen.~~ **Resolved during M3 task 4.5:** picked **single-building (a canonical half-timber house on grass)**. Spike data on the single-building reference was strong enough to commit without burning a second API call for a comparison variant. If PR review surfaces inter-register cohesion issues (e.g., ports and ships drift from the village register), re-run `make sprites-reference` with a multi-building suffix in `reference.py`.
- **Q2.** Goods icon cell size. The 1536×1024 sheet at 384×512 cells works for buildings; for 24×24 native icons a different grid is needed. Likely 6 cells of 256×256 in a 1536×512 sheet. Validated by a `good-wood` + `good-planks` regen before the full goods migration commits. **Resolved during M1.6 catalog authoring:** each `good-*` catalog declares its own 1×1 grid at `sheet_size = "256x256"` (front-matter override). The batcher MAY pack multiple goods into a shared multi-cell sheet at orchestration time without changing the catalog format.
- **Q3.** Should `pipeline.toml` declare per-kind cell-size overrides, or do we accept one cell-size per catalog entry's front matter? **Resolved: per-entry front matter.** `pipeline.toml` carries only the global defaults (`sheet_default_size`, `cell_default_grid`); catalog entries override via YAML front-matter `sheet_size` and `cell_grid` keys. Used by `ship.md` (`8x2`) and every `good-*.md` (`1x1`).
- **Q4.** Concurrency cap. Spike used 4-way concurrent calls. OpenAI rate limits for image gen are generous but not infinite; for ~20 sprite kinds at 4-way concurrency, total wall-clock is ~30s, well within tier limits. Defer harder concurrency-cap policy to first contributor running into a 429.
- **Q5.** Where does `Resources/Sprites.style/` get bundled? It is source material, not runtime assets. **Decision:** explicitly excluded from app target bundle resources via `project.yml`. Only the generated atlas PNGs ship.
- **Q6.** Shore-building catalog layout: 4 separate files per orientation or one file with 4 sub-sheets? **Resolved during M1.4 catalog authoring:** **4 separate files per orientation** (`building-port-{n,s,e,w}.md`, `building-shipyard-{n,s,e,w}.md` — 8 files total). Each orientation is a visually distinct sheet (the building faces a different direction; pier/slipway geometry differs), so each is its own generation call. This keeps the `slice_plan(catalog_entry)` contract one-sheet-per-entry.
