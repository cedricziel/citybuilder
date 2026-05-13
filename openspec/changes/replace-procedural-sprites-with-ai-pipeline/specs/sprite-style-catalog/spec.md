## ADDED Requirements

### Requirement: Style bible declares the world's visual identity
A natural-language style bible SHALL exist at `Resources/Sprites.style/world.md`. The file SHALL declare, at minimum, the following sections as level-2 Markdown headings: `Theme & era`, `Visual references`, `Projection & scale`, `Palette`, `Outline & shading`, `Background`, `Forbidden`. The file is the single source of truth for the game's visual identity — every sprite generation prompt MUST be composed from its contents.

#### Scenario: Style bible file exists
- **WHEN** the repository is inspected after this change archives
- **THEN** `Resources/Sprites.style/world.md` exists and is non-empty

#### Scenario: Style bible declares all required sections
- **WHEN** a test parses `Resources/Sprites.style/world.md` for level-2 headings
- **THEN** the parsed heading set includes `Theme & era`, `Visual references`, `Projection & scale`, `Palette`, `Outline & shading`, `Background`, and `Forbidden`

#### Scenario: Style bible declares the magenta chroma-key colour
- **WHEN** the `Background` section of `world.md` is read
- **THEN** it names the colour `#FF00FF` (case-insensitive) as the chroma-key fill

### Requirement: Master reference image anchors inter-sprite cohesion
A committed binary `Resources/Sprites.style/master-reference.png` SHALL exist. It is the visual style anchor attached to every per-sprite generation call. Regeneration of `master-reference.png` SHALL be an explicit, separate workflow (`make sprites-reference`) — `make sprites` MUST NOT regenerate it implicitly. The committed file is treated as authoritative; pipeline runs reference it on disk.

#### Scenario: Master reference exists and is a PNG
- **WHEN** the repository is inspected after this change archives
- **THEN** `Resources/Sprites.style/master-reference.png` exists and `file(1)` reports it as a PNG image

#### Scenario: make sprites does not regenerate master reference
- **WHEN** `make sprites` runs with `master-reference.png` unmodified
- **THEN** the file's mtime and content hash are unchanged after the command completes

#### Scenario: make sprites-reference is the only path to regenerate
- **WHEN** the `Makefile` is inspected for the target `sprites-reference`
- **THEN** the target exists and its recipe invokes the AI pipeline with the `--regenerate-reference` flag (or equivalent), and no other target regenerates `master-reference.png`

### Requirement: Per-sprite catalog covers every sprite kind
A natural-language catalog entry SHALL exist at `Resources/Sprites.style/catalog/<id>.md` for every sprite kind enumerated by the CityRender2D `SpriteAtlas` catalog. The catalog set MUST exactly match the sprite-kind set declared in code — no orphan catalog entries, no uncatalogued sprite kinds.

#### Scenario: Every code-declared sprite kind has a catalog entry
- **WHEN** a test enumerates every sprite kind referenced by the `SpriteAtlas` catalog (terrain kinds, land-only building kinds, shore building kinds, walker, ship, plus goods icons)
- **THEN** for each kind there exists a matching `Resources/Sprites.style/catalog/<id>.md` file where `<id>` is the kind's canonical kebab-case identifier

#### Scenario: No orphan catalog entries
- **WHEN** every file under `Resources/Sprites.style/catalog/*.md` is enumerated
- **THEN** each file's basename matches a sprite kind referenced by the `SpriteAtlas` catalog

### Requirement: Catalog entry declares function, identity, sheet, animation
Each `catalog/<id>.md` entry SHALL declare, at minimum, the following sections as level-2 Markdown headings: `Function`, `Visual identity`, `Sheet`, `Animation`. The `Sheet` section MUST enumerate every cell of the sprite sheet by `(row, col)` coordinate and assign each cell to either a specific atlas filename (e.g., `building-sawmill-operational-0`), a `spare` placeholder (solid magenta), or a construction stage. The `Animation` section MUST identify which cells form an animation loop and MUST state explicitly that frames are placed in adjacent cells.

#### Scenario: Catalog entry declares all required sections
- **WHEN** a test parses any `Resources/Sprites.style/catalog/<id>.md` for level-2 headings
- **THEN** the parsed heading set includes `Function`, `Visual identity`, `Sheet`, and `Animation`

#### Scenario: Sheet section enumerates every cell
- **WHEN** the `Sheet` section of a catalog entry declaring an N×M cell grid is parsed
- **THEN** N×M cell assignments are present, each tagged by `(row, col)` coordinate

#### Scenario: Animation frames are declared adjacent
- **WHEN** the `Animation` section of a catalog entry declares K animation frames at cells `(r0,c0), (r1,c1), ...`
- **THEN** every consecutive pair of cells in that sequence shares either a row or a column AND the column distance is at most 1 (i.e., truly adjacent in the grid)

### Requirement: Sheet cells map deterministically to atlas filenames
A pure function `slice_plan(catalog_entry) -> [(cell_coord, atlas_filename)]` SHALL exist as the contract between the sheet layout declared in `catalog/<id>.md` and the output PNG filenames written into `Resources/{Terrain,Buildings,Units,Icons}.atlas/`. Output filenames produced by `slice_plan` MUST conform to the `sprite-asset-pipeline` naming grammar (capability `sprite-asset-pipeline`, Requirement: Sprite naming grammar). The function MUST be deterministic — equal inputs produce equal outputs.

#### Scenario: Slice plan covers every catalog cell exactly once
- **WHEN** `slice_plan` is invoked on a catalog entry with N×M cells
- **THEN** the returned list has exactly N×M tuples, each cell coordinate appears exactly once, and `spare` cells produce no output filename (cell is skipped, not written)

#### Scenario: Output filenames conform to the naming grammar
- **WHEN** `slice_plan` is invoked on every shipped catalog entry
- **THEN** every produced atlas filename matches the grammar declared in capability `sprite-asset-pipeline`

#### Scenario: slice_plan is deterministic
- **WHEN** `slice_plan` is invoked twice on the same catalog entry contents
- **THEN** both invocations return equal lists of tuples in equal order

### Requirement: Prompt-hash cache controls regeneration
The pipeline SHALL maintain a content-addressed cache under `Resources/Sprites.style/_cache/` (gitignored). The cache key for a sprite kind `<id>` MUST be `sha256(world.md_content || catalog/<id>.md_content || fixed_instructions_string || model_id_string)`. A cache hit SHALL skip the API call and reuse the cached sheet for slicing. A cache miss SHALL trigger an API call and write the result into the cache before slicing. `make sprites` MUST be idempotent — re-runs with unchanged inputs perform zero API calls.

#### Scenario: Cache hit skips the API call
- **WHEN** `make sprites` runs with an entry whose cache key matches an existing `_cache/<hash>.png`
- **THEN** no HTTPS request is made to `api.openai.com` for that entry and the cached PNG is sliced

#### Scenario: Editing world.md invalidates every cache entry
- **WHEN** `world.md` is modified
- **THEN** the cache keys for every catalog entry change (since the world.md content is part of every key), forcing re-generation on the next `make sprites`

#### Scenario: Editing one catalog entry invalidates only that entry's cache
- **WHEN** only `Resources/Sprites.style/catalog/sawmill.md` is modified
- **THEN** the cache key for sawmill changes and every other entry's cache key is unchanged

#### Scenario: make sprites is idempotent on unchanged inputs
- **WHEN** `make sprites` is invoked twice in succession with no input changes between runs
- **THEN** the second run performs zero API calls and produces identical PNG bytes for every output path as the first run

### Requirement: Model version is pinned in the catalog
The pipeline SHALL pin the OpenAI image model identifier in a single committed location — `Resources/Sprites.style/pipeline.toml` — using a dated snapshot identifier (e.g., `gpt-image-2-2026-04-21`), never a floating alias. Changing the model identifier MUST invalidate every cache entry (because the model id is part of every cache key).

#### Scenario: Pipeline pins a dated model snapshot
- **WHEN** `Resources/Sprites.style/pipeline.toml` is parsed
- **THEN** the `model` key has the form `gpt-image-<major>-<YYYY>-<MM>-<DD>`, not a floating alias like `gpt-image-latest`

#### Scenario: Bumping the model invalidates every cache entry
- **WHEN** the `model` key in `pipeline.toml` changes from version A to version B
- **THEN** every catalog entry's cache key recomputes to a different value than the version-A key

### Requirement: Two-pass coherence escape hatch
A catalog entry MAY opt into a two-pass coherence mode by declaring `two-pass: true` in a YAML front-matter block at the top of `<id>.md`. In two-pass mode, the pipeline SHALL run pass-1 (design + construction stages, with operational cells left blank/spare) then pass-2 (`/v1/images/edits` using the pass-1 base cell as reference, producing only the operational animation frames). The default for entries without the flag is single-pass. The flag MUST be documented in the README sprite workflow section.

#### Scenario: Default mode is single-pass
- **WHEN** a catalog entry has no `two-pass` front-matter key
- **THEN** the pipeline composes one prompt and makes one `/v1/images/edits` call for that entry

#### Scenario: Opt-in two-pass triggers a second API call
- **WHEN** a catalog entry declares `two-pass: true` in its front matter
- **THEN** the pipeline makes exactly two `/v1/images/edits` calls for that entry: a pass-1 generating base + construction-stage cells, and a pass-2 generating operational animation cells from the pass-1 base cell as reference

#### Scenario: Two-pass cache key includes the mode
- **WHEN** an entry toggles `two-pass: true` ↔ `false`
- **THEN** its cache key changes (the mode is part of the `fixed_instructions_string` component)
