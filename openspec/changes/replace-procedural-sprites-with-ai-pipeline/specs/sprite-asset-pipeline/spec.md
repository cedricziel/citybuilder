## ADDED Requirements

### Requirement: PNG contents are produced by the style-catalog pipeline
Every sprite PNG under `Resources/{Terrain,Buildings,Units,Icons}.atlas/` SHALL be produced by the pipeline defined in capability `sprite-style-catalog`. The procedural Swift sprite generator MUST NOT be invoked as the source of truth for any committed atlas PNG after this change archives. The existing requirements in this capability (atlas layout, naming grammar, atlas routing, asset-presence validation, variant slots, sprite inventories) continue to govern the OUTPUT shape; this requirement governs the INPUT shape.

#### Scenario: Every committed atlas PNG has a catalog entry
- **WHEN** every PNG under `Resources/{Terrain,Buildings,Units,Icons}.atlas/` is enumerated and its filename routed back to a sprite kind
- **THEN** a corresponding `Resources/Sprites.style/catalog/<id>.md` exists for each routed kind

#### Scenario: Atlas PNG bytes match the pipeline output for the committed catalog
- **WHEN** `make sprites` runs against the committed catalog and cache, producing fresh atlas PNGs in a scratch directory
- **THEN** every produced PNG is byte-identical to the corresponding committed PNG under `Resources/*.atlas/`

### Requirement: Procedural sprite generator is retired
The file `scripts/generate-sprites.swift` SHALL NOT exist at its legacy path after this change archives. It MAY be quarantined under `scripts/legacy/generate-sprites.swift` for one release as visual reference; that quarantine path MUST NOT be referenced by the `Makefile`, by README workflow sections, or by any `make` target. A subsequent change SHALL delete the quarantined copy.

#### Scenario: Legacy path is empty
- **WHEN** the repository is inspected after this change archives
- **THEN** the path `scripts/generate-sprites.swift` does not exist

#### Scenario: Makefile references no procedural targets
- **WHEN** the `Makefile` is grepped for `generate-sprites.swift`
- **THEN** zero matches are found

#### Scenario: README references no procedural workflow
- **WHEN** `README.md` is grepped for `generate-sprites.swift`
- **THEN** zero matches are found

### Requirement: Hermetic regeneration via make sprites
A `make sprites` target SHALL exist and SHALL regenerate every atlas PNG from `Resources/Sprites.style/` (the style catalog) and `Resources/Sprites.style/_cache/` (the prompt-hash cache). When every cache entry is hit, `make sprites` MUST complete with zero network calls and produce byte-identical PNGs to those currently committed. CI SHALL invoke `make sprites --offline` (or equivalent flag) which fails fast on any cache miss, guaranteeing that committed atlas PNGs always have their generating inputs (catalog + cache) committed alongside them.

#### Scenario: make sprites target exists
- **WHEN** the `Makefile` is parsed for declared targets
- **THEN** a target named `sprites` is present

#### Scenario: Offline regen reproduces committed PNGs
- **WHEN** `make sprites --offline` is invoked from a clean checkout with no `OPENAI_API_KEY` set
- **THEN** the command succeeds and the resulting atlas PNGs are byte-identical to the committed PNGs

#### Scenario: CI fails on a cache miss
- **WHEN** a contributor commits a catalog edit without committing the corresponding cache PNG and pushes
- **THEN** the CI `make sprites --offline` step fails with an error naming the missing cache key

#### Scenario: Local regen with key fills the cache
- **WHEN** a contributor with `OPENAI_API_KEY` set runs `make sprites` after a cache-miss-inducing catalog edit
- **THEN** the cache is populated, the atlas PNGs are written, and a subsequent `make sprites --offline` reproduces the same outputs
