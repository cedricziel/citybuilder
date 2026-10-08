# sprite-asset-pipeline Specification

## Purpose
TBD - created by archiving change add-sprite-atlas-layout. Update Purpose after archive.
## Requirements
### Requirement: Category-atlas folder layout
The asset pipeline SHALL organize sprite PNGs into exactly three category atlases under the `Resources/` directory, each implemented as a SpriteKit `.atlas` folder: `Terrain.atlas/`, `Buildings.atlas/`, and `Units.atlas/`. No sprite PNG SHALL exist under any other path. The legacy `Resources/Sprites/` directory MUST NOT exist after this change archives.

#### Scenario: Terrain atlas exists
- **WHEN** the repository is inspected after this change archives
- **THEN** `Resources/Terrain.atlas/` exists and contains every `terrain-*.png` referenced by the sprite catalog

#### Scenario: Buildings atlas exists
- **WHEN** the repository is inspected after this change archives
- **THEN** `Resources/Buildings.atlas/` exists and contains every `building-*.png` referenced by the sprite catalog

#### Scenario: Units atlas exists
- **WHEN** the repository is inspected after this change archives
- **THEN** `Resources/Units.atlas/` exists and contains every `walker-*.png` referenced by the sprite catalog

#### Scenario: Legacy sprite directory removed
- **WHEN** the repository is inspected after this change archives
- **THEN** `Resources/Sprites/` does not exist

### Requirement: Sprite naming grammar
Sprite PNG filenames SHALL conform to one of the grammars below based on category. A new optional `-vN` slot encodes per-tile art variants — visually distinct PNGs the renderer picks per tile from the catalog. Variant 0 is implicit (uses the canonical stem with no suffix); variants 1..N-1 use the literal `v` prefix followed by a non-negative integer.

- Terrain: `terrain-<kind>[-v<variant>][-<frame>].png` where `<kind>` is a value from `TerrainKind`, `<variant>` is a positive integer when the kind opts into per-tile art variants (the canonical sprite omits the slot), and `<frame>` is a non-negative integer when the sprite is animated.
- Building (land-only): `building-<kind>[-v<variant>][-<state>][-<frame>].png` where `<kind>` is a value from `BuildingKind`, `<variant>` is a positive integer when the kind opts into per-tile art variants, `<state>` is one of `constructing` or `operational` (omitted for the idle baseline sprite), and `<frame>` is a non-negative integer when the sprite is animated.
- Building (shore): `building-<kind>-<orientation>[-<state>][-<frame>].png` where `<orientation>` is one of `n`, `s`, `e`, `w` denoting the cardinal direction of the building's water side, `<state>` and `<frame>` follow the same rules as the land-only building grammar. Shore buildings do NOT opt into the variant slot; orientation already provides the per-tile differentiation. The shore grammar applies exclusively to building kinds that opt into the `shorePlacement` rule (per `buildings-and-construction`).
- Unit (walker): `walker-<facing>-<frame>.png` where `<facing>` is one of `ne`, `nw`, `se`, `sw` and `<frame>` is a non-negative integer. Walkers do NOT opt into the variant slot.
- Unit (ship): `ship-<facing>-<frame>.png` where `<facing>` is one of `n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw` and `<frame>` is a non-negative integer. Ships do NOT opt into the variant slot.

The slot order for terrain and land-only buildings is fixed: `<kind>` → optional `<variant>` → optional `<state>` (buildings only) → optional `<frame>`. Variant slots SHALL never collide with frame digits because the variant slot is literally `v<digit>` whereas the frame slot is a bare digit.

Filenames MUST remain lowercase, hyphen-separated, with no spaces, underscores, or non-ASCII characters (unchanged from the prerequisite atlas-layout change).

#### Scenario: Conformant shore-building name accepted
- **WHEN** the catalog declares `building-port-w-operational-1`
- **THEN** name validation passes

#### Scenario: Conformant shore-building idle baseline accepted
- **WHEN** the catalog declares `building-port-n` (orientation, no state, no frame)
- **THEN** name validation passes

#### Scenario: Conformant ship name accepted
- **WHEN** the catalog declares `ship-ne-1`
- **THEN** name validation passes

#### Scenario: Shore-building name without orientation rejected
- **WHEN** the catalog declares `building-port-operational-0` (orientation slot missing for a shore building kind)
- **THEN** name validation fails with reason code `shore_building_missing_orientation`

#### Scenario: Ship name with cardinal-only facing rejected
- **WHEN** the catalog declares `ship-ne-0` for a build that has not extended the unit grammar (regression guard)
- **THEN** name validation passes only after this change archives; prior to that, the legacy walker-style 4-facing validator would have rejected it

#### Scenario: Ship name with unknown facing rejected
- **WHEN** the catalog declares `ship-northeast-0` (long-form facing)
- **THEN** name validation fails with reason code `ship_facing_unknown`

#### Scenario: Variant slot accepted for terrain
- **WHEN** the catalog declares `terrain-mountain-v2`
- **THEN** name validation passes

#### Scenario: Variant slot accepted for land-only building
- **WHEN** the catalog declares `building-road-v3`
- **THEN** name validation passes

#### Scenario: Variant slot rejected on shore building
- **WHEN** the catalog declares `building-port-v1-n` (variant slot on a shore-grammar kind)
- **THEN** name validation fails because shore kinds do not opt into the variant slot

### Requirement: Atlas routing by sprite-name prefix
The `SpriteAtlas` type SHALL resolve every sprite name by routing the lookup to the category atlas indicated by the name's prefix, per the following extended table:

| Prefix | Atlas |
|---|---|
| `terrain-` | `Terrain` |
| `building-` | `Buildings` |
| `walker-` | `Units` |
| `ship-` | `Units` |

The public `SpriteAtlas` API remains unchanged.

#### Scenario: Ship name routes to Units atlas
- **WHEN** `SpriteAtlas.texture(for: "ship-ne-0")` is called
- **THEN** the lookup is performed against `SKTextureAtlas(named: "Units")` and returns a non-nil texture

#### Scenario: Shore-building name routes to Buildings atlas
- **WHEN** `SpriteAtlas.texture(for: "building-port-w-operational-1")` is called
- **THEN** the lookup is performed against `SKTextureAtlas(named: "Buildings")` and returns a non-nil texture

### Requirement: SpriteAtlas resolves via category atlases
The `SpriteAtlas` SHALL hold lazy references to the three category `SKTextureAtlas` instances and resolve every sprite name through them. No code path inside `SpriteAtlas` SHALL call `SKTexture(imageNamed:)` directly for sprite assets covered by the catalog.

#### Scenario: No imageNamed lookups in SpriteAtlas
- **WHEN** the CityRender2D test suite runs a code-scan check over `SpriteAtlas` sources
- **THEN** no occurrence of `SKTexture(imageNamed:` is found within the type's implementation

#### Scenario: SKTextureAtlas instances are lazily constructed
- **WHEN** `SpriteAtlas` is initialized
- **THEN** the underlying `SKTextureAtlas` instances are not yet constructed; they are constructed on first lookup against each category

### Requirement: Asset-presence validation at startup
In debug builds, on first construction of `SpriteAtlas`, the type SHALL iterate every sprite name declared in the catalog and assert that the corresponding texture resolves to a non-nil result. Violations MUST be reported via a `precondition` failure with the missing sprite name. In release builds this check MUST be elided.

#### Scenario: Missing sprite fails fast in debug
- **WHEN** a debug build constructs `SpriteAtlas` with a catalog that declares `building-missing` and no such PNG exists in `Buildings.atlas`
- **THEN** a `precondition` failure fires with a message naming `building-missing`

#### Scenario: Release build does not perform the presence check
- **WHEN** a release build constructs `SpriteAtlas` with the same catalog as above
- **THEN** no presence check runs and construction succeeds (the renderer falls back to placeholder textures at draw time, per `rendering-2_5d`)

#### Scenario: Complete catalog passes silently in debug
- **WHEN** a debug build constructs `SpriteAtlas` with a catalog where every declared sprite exists in its expected atlas
- **THEN** construction completes without any precondition failure

### Requirement: Ship sprite inventory
The sprite catalog SHALL declare exactly 16 ship sprite entries: the cross product of facings `{n, ne, e, se, s, sw, w, nw}` and frames `{0, 1}`. Every declared ship sprite MUST resolve to a non-nil texture in `Units.atlas` (verified by the asset-presence check from `sprite-asset-pipeline`).

#### Scenario: All 16 ship sprites declared
- **WHEN** the sprite catalog is enumerated
- **THEN** there are exactly 16 entries matching the pattern `ship-<facing>-<frame>` covering every (facing, frame) pair

#### Scenario: Every declared ship sprite resolves
- **WHEN** the debug-build asset-presence check runs on a build containing this change's PNGs
- **THEN** every declared `ship-<facing>-<frame>` resolves to a non-nil texture from `Units.atlas`

### Requirement: Shore-building sprite inventory
For every building kind opting into the `shorePlacement` rule, the sprite catalog SHALL declare exactly 24 sprite entries per kind: the cross product of orientations `{n, s, e, w}` and the state/frame matrix `{(idle, none), (constructing, 0), (constructing, 1), (constructing, 2), (operational, 0), (operational, 1)}`. Port and Shipyard SHALL be the initial shore-placement opt-ins.

#### Scenario: All 24 port sprites declared
- **WHEN** the sprite catalog is enumerated for the Port kind
- **THEN** there are exactly 24 entries matching the shore-building grammar covering every (orientation, state, frame) tuple

#### Scenario: All 24 shipyard sprites declared
- **WHEN** the sprite catalog is enumerated for the Shipyard kind
- **THEN** there are exactly 24 entries matching the shore-building grammar covering every (orientation, state, frame) tuple

#### Scenario: Every declared shore-building sprite resolves
- **WHEN** the debug-build asset-presence check runs on a build containing this change's PNGs
- **THEN** every declared `building-<kind>-<orientation>[-<state>-<frame>]` for Port and Shipyard resolves to a non-nil texture from `Buildings.atlas`

### Requirement: Sprite catalog declares new content
The sprite catalog declared in CityRender2D SHALL be extended to register the 16 ship entries and the 48 shore-building entries (24 Port + 24 Shipyard) introduced by this change. Catalog extensions MUST be additive — no existing entry's name, atlas, or resolved texture SHALL change as a result of this requirement.

#### Scenario: Catalog count grows by exactly 64
- **WHEN** the catalog entry count before this change is `B` and the count after is `A`
- **THEN** `A - B == 64`

#### Scenario: Pre-existing catalog entries unchanged
- **WHEN** the catalog is compared entry-by-entry between the pre-archive state of this change and the post-archive state
- **THEN** every entry that existed before this change is present with identical name and identical resolved-atlas routing afterwards

### Requirement: Per-tile art variants
A subset of terrain and land-only building kinds SHALL ship multiple visually distinct sprites under the variant slot of the naming grammar (per the modified `Sprite naming grammar` requirement). The renderer SHALL pick one variant per tile via a deterministic function of the tile coordinate so that the choice is stable across replays, snapshots, and renderer reconciliations of equal `World` values.

Per-kind variant counts SHALL be declared in two `SpriteAtlas` constants — `terrainVariantCounts: [TerrainType: Int]` and `buildingVariantCounts: [BuildingKind: Int]`. A kind absent from its table renders only the canonical sprite (variant 0). The initial variant inventory SHALL be:
- `terrainVariantCounts[.mountain] = 4`
- `buildingVariantCounts[.road] = 4`

Variant selection SHALL be implemented by a pure function `SpriteAtlas.variantIndex(coord:count:)` that takes a `TileCoordinate` and the variant count and returns an integer in `0..<count`. The function SHALL be a deterministic function of its inputs alone, with no dependence on RNG, the live `World`, or any external state.

#### Scenario: Mountain ships four art variants
- **WHEN** the sprite catalog is enumerated for the mountain terrain kind
- **THEN** four entries are present: `terrain-mountain` (variant 0) and `terrain-mountain-v1`, `terrain-mountain-v2`, `terrain-mountain-v3`

#### Scenario: Road ships four art variants
- **WHEN** the sprite catalog is enumerated for the road building kind
- **THEN** four entries are present: `building-road` (variant 0) and `building-road-v1`, `building-road-v2`, `building-road-v3`

#### Scenario: Variant selection is a pure function of coord and count
- **WHEN** `SpriteAtlas.variantIndex(coord: TileCoordinate(x: 12, y: 7), count: 4)` is called twice
- **THEN** both calls return the same integer in `0..<4`

#### Scenario: Variant selection is in-range
- **WHEN** `SpriteAtlas.variantIndex(coord: c, count: n)` is called for any `c` and any `n > 0`
- **THEN** the result is in the half-open interval `0..<n`

#### Scenario: Variant zero when count is one
- **WHEN** `SpriteAtlas.variantIndex(coord: c, count: 1)` is called for any `c`
- **THEN** the result is `0`

#### Scenario: Distinct coords map across the full variant range
- **WHEN** `SpriteAtlas.variantIndex(coord:count:)` is called for every integer coord in a 16×16 region with count `4`
- **THEN** every variant index `0`, `1`, `2`, `3` appears at least once in the resulting distribution

### Requirement: Variant assets enforced by catalog presence check
The sprite catalog SHALL enumerate every variant PNG declared in `terrainVariantCounts` and `buildingVariantCounts`. The asset-presence check from `sprite-asset-pipeline` SHALL fail in debug builds if any declared variant PNG is missing from its category atlas. The check MUST cover both variant 0 (canonical stem) and variants 1..N-1 (`-vN` form).

#### Scenario: Missing variant PNG fails the debug catalog check
- **WHEN** a debug build constructs `SpriteAtlas` with `terrainVariantCounts[.mountain] = 4` but `Resources/Terrain.atlas/terrain-mountain-v2.png` is missing
- **THEN** a `precondition` failure fires with a message naming `terrain-mountain-v2`

#### Scenario: Complete variant inventory passes the debug catalog check
- **WHEN** a debug build constructs `SpriteAtlas` with every variant PNG declared by the variant-count tables present in its atlas
- **THEN** construction completes without any precondition failure

### Requirement: Renderer picks variants per tile coord
The `IsoWorldScene` scene factory SHALL resolve the texture for a terrain or land-only building sprite spec via the variant-aware lookup keyed on `spec.coord`. The ghost preview path SHALL use the same lookup keyed on the ghost's target tile so the preview matches what the placed tile will render.

#### Scenario: Placed mountain tile picks its variant from its coord
- **WHEN** the snapshot reconciler emits a mountain terrain spec at coord `(x, y)`
- **THEN** the renderer node's texture is `SpriteAtlas.terrainTextureOrPlaceholder(for: .mountain, coord: TileCoordinate(x: x, y: y))`

#### Scenario: Placed road tile picks its variant from its coord
- **WHEN** the snapshot reconciler emits a road building spec at coord `(x, y)` in operational state
- **THEN** the renderer node's texture is `SpriteAtlas.buildingTextureOrPlaceholder(for: .road, coord: TileCoordinate(x: x, y: y))`

#### Scenario: Ghost preview matches placement variant
- **WHEN** the ghost preview is reconciled for a road build at coord `(x, y)`
- **THEN** the ghost node's texture is the same texture the placed tile would receive at coord `(x, y)`

### Requirement: Good-prefix sprite name grammar

The sprite-name grammar SHALL accept the prefix `good-` for good icons, in addition to the existing `terrain-`, `building-`, and `walker-` prefixes. The `SpriteAtlasRouting` table MUST map `good-*` names to a new `Icons` atlas. Validation MUST continue to reject names with uppercase letters or underscores.

#### Scenario: Sprite-name grammar accepts good- prefix

- **WHEN** `SpriteName.validate("good-wood")` is called
- **THEN** the validator returns `.success`

#### Scenario: SpriteAtlasRouting routes good- to Icons atlas

- **WHEN** `SpriteAtlasRouting.atlasName(for: "good-wood")` is called
- **THEN** it returns `"Icons"`

#### Scenario: Validator rejects good- with underscore

- **WHEN** `SpriteName.validate("good-iron_ore")` is called
- **THEN** the validator returns `.failure(.spriteNameUsesUnderscore)`

### Requirement: Procedurally generated good icons

The `scripts/generate-sprites.swift` script SHALL emit three 24×24 PNG icons to `Resources/Icons.atlas/`: `good-wood.png`, `good-planks.png`, `good-food.png`. The icons MUST be drawn at the same nearest-neighbor pixel-art fidelity as the rest of the sprite output and bundled into the same `*.atlas` directory layout the existing sprite atlases use.

#### Scenario: Generator emits three good icons

- **WHEN** `swift scripts/generate-sprites.swift` is run
- **THEN** `Resources/Icons.atlas/good-wood.png`, `Resources/Icons.atlas/good-planks.png`, and `Resources/Icons.atlas/good-food.png` are present, each 24×24, non-empty

### Requirement: Terrain sprites fill the iso diamond

Every committed terrain sprite (`terrain-*`) SHALL cover at least 90% of the 64×32 iso diamond mask with opaque pixels (alpha ≥ the pipeline's soft-alpha threshold), and MUST NOT place more than 2% of its opaque pixels outside the diamond. The pipeline SHALL apply a diamond-fit normalisation step to terrain output: scale the opaque bounding box to the diamond's extent, then clip with the diamond mask. Adjacent terrain tiles therefore tile without gaps.

#### Scenario: Every committed terrain sprite fills the diamond

- **WHEN** the content gate inspects every PNG in `Resources/Terrain.atlas/`
- **THEN** each one covers at least 90% of the diamond and has no more than 2% of its opaque pixels outside it

#### Scenario: Content gate rejects an under-filled terrain sprite

- **WHEN** the content gate inspects a committed `terrain-grass.png` that covers 36% of the diamond
- **THEN** the gate fails and names `terrain-grass.png` with reason `terrain_coverage_below_threshold`

### Requirement: Sprite frames are never empty

Every committed sprite PNG in a category atlas SHALL contain at least one opaque pixel. The content gate MUST fail on a fully transparent frame.

#### Scenario: Content gate rejects a fully transparent frame

- **WHEN** the content gate inspects a committed `terrain-water-2.png` with zero opaque pixels
- **THEN** the gate fails and names `terrain-water-2.png` with reason `frame_empty`

### Requirement: Animation frames stay coherent with their base sprite

For every sprite that declares animation frames (`<name>-0` … `<name>-N`) or art variants (`<name>-v1` … `<name>-vN`), each frame and variant SHALL stay visually coherent with the base `<name>.png`. The palette-histogram distance between the frame and the base, computed over 16 quantised luminance-hue bins on opaque pixels, MUST NOT exceed the threshold pinned in `pipeline.toml` (`coherence_max_distance`). The content gate MUST fail on any frame above the threshold.

#### Scenario: Content gate rejects a frame that depicts a different object

- **WHEN** the content gate compares `terrain-water-1.png` (a house) against the `terrain-water.png` base (water)
- **THEN** the gate fails and names `terrain-water-1.png` with reason `frame_incoherent`

#### Scenario: Content gate accepts coherent water frames

- **WHEN** the content gate compares four water frames that differ only in glint placement against their water base
- **THEN** the gate passes for all four frames

### Requirement: Operational frames share one silhouette

Every building operational frame (`<name>-operational-N`) SHALL keep the base sprite's silhouette: the left, right and bottom edges of its opaque bounding box MUST lie within 2 pixels of the base sprite's. The top edge is exempt, so effects such as chimney smoke may rise above the roof. The content gate MUST fail on a frame outside this tolerance with reason `frame_misaligned`. Catalog entries MAY declare `operational = "derived"` to have the pipeline build their operational frames from the base sprite, which satisfies this rule by construction.

#### Scenario: Content gate rejects a shifted operational frame

- **WHEN** the content gate compares `building-sawmill-operational-0.png`, whose building sits 6 pixels left of the base sprite's, against `building-sawmill.png`
- **THEN** the gate fails and names `building-sawmill-operational-0.png` with reason `frame_misaligned`

#### Scenario: Content gate accepts smoke above the roof

- **WHEN** an operational frame matches its base sprite except for smoke pixels drawn above the roof line
- **THEN** the gate reports no `frame_misaligned` failure for that frame

### Requirement: Overlay sprites route to the Buildings atlas

Sprite names with the `overlay-` prefix (status badges drawn over buildings) SHALL route to the `Buildings` atlas, where they are committed.

#### Scenario: Waiting badge routes to the Buildings atlas

- **WHEN** `SpriteAtlasRouting.atlasName(for: "overlay-waiting-materials")` is called
- **THEN** it returns `"Buildings"`

### Requirement: Content gate runs in sprite verification

`make sprites-verify` and the CI sprite job SHALL run the content gate after the byte-identical regen check. The job MUST exit non-zero if any content-gate rule fails, and it MUST print every failing sprite with its reason code, one per line.

#### Scenario: Verification fails on a content defect even when bytes reproduce

- **WHEN** `make sprites-verify` runs against an atlas whose PNGs reproduce byte-for-byte from the cache but where one frame is fully transparent
- **THEN** the command exits non-zero and prints the empty frame's file name with reason `frame_empty`

### Requirement: Committed PNGs are indexed-mode and optimized
Every committed PNG under `Resources/{Terrain,Buildings,Units,Icons}.atlas/` and `Resources/Sprites.style/` (including `master-reference.png` and every `_sheets/<id>.png`) SHALL be encoded as an **indexed-mode PNG with a palette of at most 256 colours** and written with `optimize=True` (Pillow) or the equivalent compression-maximizing flag in any future tooling. RGB or RGBA truecolor PNGs MUST NOT be committed. The committed footprint per binary stays an order of magnitude smaller than truecolor — repo size is a load-bearing concern for clone times.

Rationale: pixel-art sprites have at most ~32 distinct colours in their actual palette (the world.md palette), so indexed encoding loses zero visual fidelity while cutting file size 2–3×. The pre-commit check that rejects files >1 MB exists for the same reason; indexed encoding keeps every sprite well under that bar.

#### Scenario: Every committed sprite PNG is indexed-mode
- **WHEN** every `*.png` under `Resources/{Terrain,Buildings,Units,Icons}.atlas/` and `Resources/Sprites.style/` is inspected
- **THEN** Pillow `Image.open(path).mode` reports `P` (indexed) for each — never `RGB`, never `RGBA` truecolor

#### Scenario: Pipeline writes indexed-mode PNGs by default
- **WHEN** the pipeline writes any output PNG (atlas, `_sheets/`, `master-reference.png`)
- **THEN** the file is saved with at most a 256-colour palette and `optimize=True`

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
