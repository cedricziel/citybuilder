## 1. M0 — Style bible authoring

- [x] 1.1 Tests-first: translate the `Style bible declares the world's visual identity` requirement scenarios (`Style bible file exists`, `Style bible declares all required sections`, `Style bible declares the magenta chroma-key colour`) into failing `swift-testing` tests in `Packages/CityRender2D/Tests/CityRender2DTests/SpritesStyleCatalogTests.swift`. The tests parse Markdown level-2 headings from `Resources/Sprites.style/world.md`. Confirm red with `make test`.
- [x] 1.2 Author `Resources/Sprites.style/world.md` covering the seven required sections (`Theme & era`, `Visual references`, `Projection & scale`, `Palette`, `Outline & shading`, `Background`, `Forbidden`). Background section MUST name `#FF00FF` as the chroma-key.
- [x] 1.3 Implement to green: confirm `Style bible declares the world's visual identity` scenarios pass.
- [x] 1.4 Author `Resources/Sprites.style/pipeline.toml` with `model = "gpt-image-2-2026-04-21"`, `sheet_default_size = "1536x1024"`, `cell_default_grid = "4x2"`, and a `[concurrency]` section with `max_inflight = 4`. Add a tests-first failing test for the `Pipeline pins a dated model snapshot` scenario, then make it green.
- [x] 1.5 Refactor under a green bar: any shared Markdown-parsing helper between style-bible and catalog tests gets extracted to a single test utility.
- [x] 1.6 Verify `make test-scenarios` is clean for the `Style bible declares the world's visual identity` and `Model version is pinned in the catalog` requirements.

## 2. M1 — Per-sprite catalog authoring

- [x] 2.1 Tests-first: translate `Every code-declared sprite kind has a catalog entry`, `No orphan catalog entries`, `Catalog entry declares all required sections`, `Sheet section enumerates every cell`, and `Animation frames are declared adjacent` into failing tests in `SpritesStyleCatalogTests.swift`. The tests enumerate `SpriteAtlas` catalog kinds in code, walk `Resources/Sprites.style/catalog/*.md`, and parse each entry's level-2 headings + `Sheet`/`Animation` sections. Confirm red.
- [x] 2.2 Author `Resources/Sprites.style/catalog/<id>.md` for every terrain kind (matched the existing `TerrainType` enum: `grass`, `forest`, `beach`, `water`, `mountain` — note tasks.md originally listed `sand` which is not in the enum). One catalog file per terrain kind; small cell grids; static sprites have a 1-cell sheet.
- [x] 2.3 Author `catalog/<id>.md` for every land-only building kind: `town-center`, `road`, `house`, `lumberjack-hut`, `sawmill`, `warehouse`. Each declares a 4×2 sheet covering base + operational + 3 construction stages + spare per design.md §D6 cell adjacency rule.
- [x] 2.4 Author `catalog/<id>.md` for every shore building kind: `port` and `shipyard`. Picked approach: **one catalog file per (kind, orientation) tuple** — 8 files total (`building-port-{n,s,e,w}.md`, `building-shipyard-{n,s,e,w}.md`). See design.md Open Questions resolution.
- [x] 2.5 Author `catalog/walker.md` for the walker unit (4 facings × 2 frames = 8 cells). Author `catalog/ship.md` for the ship unit (8 facings × 2 frames = 16 cells; verify against `Ship sprite inventory` requirement count).
- [x] 2.6 Author `catalog/<id>.md` for every goods icon (`good-wood`, `good-planks`, `good-food`, …) using the smaller-cell-grid front-matter override per design.md §Q2.
- [x] 2.7 Implement to green: confirm every M1 scenario test passes.
- [x] 2.8 Refactor under a green bar: catalog files that share boilerplate (e.g., all shore-building catalogs sharing identical `Animation` boilerplate) get a shared snippet referenced from each — only if duplication is meaningful, otherwise leave alone. (Reviewed: each shore-orientation file has a unique geometric story; left as-is.)
- [x] 2.9 Verify `make test-scenarios` is clean for the `Per-sprite catalog covers every sprite kind`, `Catalog entry declares function, identity, sheet, animation` requirements.

## 3. M2 — Pipeline tooling foundation

- [x] 3.1 Tests-first: write failing pytest tests under `scripts/tests/test_composer.py`, `scripts/tests/test_slicer.py`, `scripts/tests/test_postprocess.py` covering `slice_plan` determinism, slice-plan-covers-every-cell, output-filenames-conform-to-naming-grammar (cross-references `sprite-asset-pipeline` grammar). Confirm red with `python -m pytest scripts/tests`.
- [x] 3.2 Author `scripts/requirements.txt` pinning `Pillow==10.4.0`, `httpx==0.27.2`, `pytest==8.3.3`, `tomli==2.0.1`. Add `make sprites-venv` target that creates `.venv/sprites/` from this file.
- [x] 3.3 Implement `scripts/generate_sprites_ai/composer.py` as the pure `(world_md, entry_md, fixed_instructions) -> Prompt` function. No I/O. No network.
- [x] 3.4 Implement `scripts/generate_sprites_ai/slicer.py` exposing `slice_plan(catalog_entry) -> [(cell_coord, atlas_filename)]` and `slice_sheet(image, plan) -> [(filename, image)]`. Pure functions; Pillow only.
- [x] 3.5 Implement `scripts/generate_sprites_ai/postprocess.py` exposing `chroma_key(image, hex_color="#FF00FF") -> image`, `downsample(image, target_size, mode="nearest"|"bicubic") -> image`, `quantize(image, palette) -> image`, `preserve_outline(image) -> image`. Pure functions.
- [x] 3.6 Implement to green: confirm M2 pure-function pytest scenarios pass.
- [x] 3.7 Refactor under a green bar: extract any shared Pillow boilerplate (mode conversion, ICC handling) to a `_image_utils.py` private module. (Reviewed: no duplication worth extracting at this size; left as-is.)
- [x] 3.8 Verify `make test-scenarios` is clean for `Sheet cells map deterministically to atlas filenames`.

## 4. M3 — Master reference image generation

- [x] 4.1 Tests-first: translate `Master reference exists and is a PNG`, `make sprites does not regenerate master reference`, `make sprites-reference is the only path to regenerate` into failing tests. The first two are file-system tests; the third is a Makefile-grep test. Confirm red.
- [x] 4.2 Resolve Open Question Q1 (single vs multi-building reference): **picked single-building (canonical half-timber house)** — see design.md §Q1 resolution. Multi-building variant was not generated because the spike data on the single-building variant was strong enough; if PR review surfaces inter-register coherence problems we'll iterate with a multi-building reference.
- [x] 4.3 Implement `scripts/generate_sprites_ai/reference.py` exposing `generate_master_reference(world_md, pipeline_toml) -> Image`. Uses `/v1/images/generations` (pure generation, no reference) seeded from `world.md`. Returns a Pillow image; caller writes to disk.
- [x] 4.4 Add `make sprites-reference` Makefile target that invokes `reference.py` and overwrites `Resources/Sprites.style/master-reference.png`. Add no-op behavior to `make sprites` so it never touches `master-reference.png`.
- [x] 4.5 Run `make sprites-reference`, commit the resulting binary, link the rendered output in the PR description for visual review.
- [x] 4.6 Implement to green: confirm M3 scenarios pass.
- [x] 4.7 Verify `make test-scenarios` is clean for `Master reference image anchors inter-sprite cohesion`.

## 5. M4 — Cache layer + batcher + make sprites

- [x] 5.1 Tests-first: translate `Cache hit skips the API call`, `Editing world.md invalidates every cache entry`, `Editing one catalog entry invalidates only that entry's cache`, `make sprites is idempotent on unchanged inputs`, and `Bumping the model invalidates every cache entry` into failing pytest tests under `scripts/tests/test_cache.py`. Mock `httpx.Client.post` to detect zero/non-zero calls. Confirm red.
- [x] 5.2 Implement `scripts/generate_sprites_ai/cache.py` exposing `cache_key(world_md, entry_md, fixed_instructions, model_id) -> str` and `read_cache(key) -> Optional[Image]`, `write_cache(key, image, api_response_json) -> None`. Storage under `Resources/Sprites.style/_cache/<hash>.{png,json}`.
- [x] 5.3 Implement the parallel committed-sheets store `Resources/Sprites.style/_sheets/<id>.png` per design.md §D5. Pipeline writes to both `_cache/` and `_sheets/` on a hit; `make sprites --offline` reads only from `_sheets/`.
- [x] 5.4 Implement `scripts/generate_sprites_ai/batcher.py` orchestrating: walk catalog, compose prompts, fan out concurrent (4-way) `/v1/images/edits` calls with master-reference attached, write cache + sheets, invoke slicer + post-process, write atlas PNGs. Only impure boundary; all other modules pure.
- [x] 5.5 Add `scripts/generate_sprites_ai/__main__.py` so `python -m generate_sprites_ai [--offline] [--regenerate-reference]` is the canonical entry point. Add `make sprites` target invoking it, plus `make sprites-offline` (synonym for `--offline`).
- [x] 5.6 Add `Resources/Sprites.style/_cache/` to `.gitignore`. Keep `_sheets/` tracked.
- [x] 5.7 Implement to green: confirm M4 cache + idempotency tests pass.
- [x] 5.8 Refactor under a green bar: any duplicated path-handling logic between `cache.py` and `batcher.py` consolidates to `_paths.py`. (Resolved: shared paths live in `paths.py`; cache.py + batcher.py both import from it.)
- [x] 5.9 Verify `make test-scenarios` is clean for `Prompt-hash cache controls regeneration`.

## 6. M5 — Full regen + cutover commit

- [ ] 6.1 Tests-first: translate `Every committed atlas PNG has a catalog entry` and `Atlas PNG bytes match the pipeline output for the committed catalog` from the `sprite-asset-pipeline` delta into failing tests in `SpritesStyleCatalogTests.swift`. Confirm red.
- [ ] 6.2 Run `make sprites` against the committed catalog with `OPENAI_API_KEY` set. Cost expectation: ~$1 for ~25 sprite kinds. Wall-clock: ~2 minutes at 4-way concurrency.
- [ ] 6.3 Visually review every regenerated PNG against its corresponding existing procedural PNG. For each building, decide: (a) accept the new art as-is, (b) edit `catalog/<id>.md` and re-run, (c) flag as needing two-pass mode for M8. Iterate until visual approval.
- [ ] 6.4 Stage the new `Resources/{Terrain,Buildings,Units,Icons}.atlas/*.png` files (mass overwrite of existing PNGs) AND the new `Resources/Sprites.style/_sheets/*.png` files. Verify `git diff --stat` matches expectations (no other files touched in this commit).
- [ ] 6.5 Run `make sprites --offline` from a clean shell (no `OPENAI_API_KEY`). Confirm zero network calls, zero changes to working tree (idempotency).
- [ ] 6.6 Implement to green: confirm `Atlas PNG bytes match the pipeline output for the committed catalog` passes (the offline run reproduces every committed PNG byte-for-byte).
- [ ] 6.7 Verify the existing `sprite-asset-pipeline` debug presence check (`SpriteAtlas` precondition validation, established in `Asset-presence validation at startup`) still passes after the regen. No name, no atlas-routing changes.
- [ ] 6.8 Verify `make test-scenarios` is clean for `PNG contents are produced by the style-catalog pipeline` and `Hermetic regeneration via make sprites`.

## 7. M6 — Procedural generator retirement

- [ ] 7.1 Tests-first: translate `Legacy path is empty`, `Makefile references no procedural targets`, and `README references no procedural workflow` into failing tests in `SpritesStyleCatalogTests.swift`. The tests grep file contents from the package test harness. Confirm red.
- [ ] 7.2 Move `scripts/generate-sprites.swift` → `scripts/legacy/generate-sprites.swift`. No content changes.
- [ ] 7.3 Remove every `Makefile` recipe that references `generate-sprites.swift` or its output paths under the old workflow. Add a deprecation banner in `scripts/legacy/README.md` naming the replacement (`scripts/generate_sprites_ai/`) and pointing to this OpenSpec change.
- [ ] 7.4 Update `README.md`: replace the "Adding a new animated sprite" section with a new section walking through editing `world.md` and `catalog/<id>.md`. Replace "Adding a new good icon" similarly. Remove every prose reference to `scripts/generate-sprites.swift`.
- [ ] 7.5 Update README's onboarding `make` ladder to include `make sprites-venv` between `make hooks` and `make generate`.
- [ ] 7.6 Implement to green: confirm M6 grep-based tests pass.
- [ ] 7.7 Verify `make test-scenarios` is clean for `Procedural sprite generator is retired`.

## 8. M7 — CI hermetic-regen check

- [ ] 8.1 Tests-first: translate `CI fails on a cache miss` and `Offline regen reproduces committed PNGs` into failing CI-shape tests. For local runs these are pytest tests that shell out to `make sprites --offline` from a temp checkout with a synthetic missing-sheet condition.
- [ ] 8.2 Add a `make sprites-verify` Makefile target that runs `make sprites --offline` in a temp directory and diffs the produced atlas PNGs against the committed ones. Exits non-zero on any diff.
- [ ] 8.3 Add `make sprites-verify` to the CI workflow (`.github/workflows/ci.yml` or whichever the project uses) as a required step. The job MUST run without `OPENAI_API_KEY` in its environment.
- [ ] 8.4 Add a pre-commit hook entry to `.pre-commit-config.yaml` that runs `scripts/check-sprite-catalog-consistency.sh` — a fast check that any catalog edit in the staged diff is paired with a corresponding `_sheets/` edit. Hook fails on inconsistency with a message naming the missing sheet.
- [ ] 8.5 Implement to green: confirm M7 scenarios pass on a synthetic broken commit (catalog edit without sheet update) and a synthetic good commit.
- [ ] 8.6 Verify `make test-scenarios` is clean for the CI-related `Hermetic regeneration via make sprites` scenarios.

## 9. M8 — Two-pass escape hatch + workflow docs

- [ ] 9.1 Tests-first: translate `Default mode is single-pass`, `Opt-in two-pass triggers a second API call`, and `Two-pass cache key includes the mode` into failing pytest tests under `scripts/tests/test_batcher.py`. Mock `httpx.Client.post` to count calls and inspect the second-pass image attachment. Confirm red.
- [ ] 9.2 Extend `batcher.py` to parse YAML front matter from each `catalog/<id>.md`. Detect `two-pass: true`; in that branch, fire pass-1 with operational cells declared as spare, then pass-2 with the pass-1 base cell attached as `image[]=` reference and operational cells declared in the prompt.
- [ ] 9.3 Update `cache.py` so the `fixed_instructions_string` component of the cache key includes the entry's `two-pass` mode (and other front-matter flags). Toggling the mode invalidates the entry's cache.
- [ ] 9.4 Apply two-pass mode to any building flagged in M5.6.3(c) as needing it; regen + visual review; commit the updated catalog + sheets + atlas PNGs.
- [ ] 9.5 Add a "Two-pass escape hatch" section to README explaining when to set `two-pass: true` (visible animation flicker in playtest), how it works (pass-1 design + construction, pass-2 animation from pass-1 base cell), and the cost (2× API spend for that building).
- [ ] 9.6 Implement to green: confirm M8 two-pass scenarios pass.
- [ ] 9.7 Refactor under a green bar: shared logic between pass-1 and pass-2 invocations consolidates if duplicated; otherwise leave alone.
- [ ] 9.8 Verify `make test-scenarios` is clean for `Two-pass coherence escape hatch`.

## 10. M9 — Visual regression playthrough

- [ ] 10.1 Run the iOS app on the simulator across a representative scenario: place a town center, build one of every building kind, advance the world ~1000 ticks. Capture screenshots at key moments: empty island, mid-build, full economy.
- [ ] 10.2 Run the Mac app through the same scenario.
- [ ] 10.3 Compare screenshots against pre-change screenshots stored in `.scratch/visual-regression/before/`. Document any sprites that read worse in-game than the procedural originals; if any block the cutover, return to M5.6.3 / M8 and iterate.
- [ ] 10.4 Run on a physical iPhone and a physical iPad — DEFERRED (requires hardware).
- [ ] 10.5 Send a TestFlight build to 2–3 internal reviewers for visual sign-off — DEFERRED (requires TestFlight account + reviewers).
- [ ] 10.6 Final verify: `make sprites --offline && make test && make test-scenarios` all green in a clean checkout.
