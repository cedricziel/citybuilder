## MODIFIED Requirements

### Requirement: Sprite naming grammar
Sprite PNG filenames SHALL conform to one of the grammars below based on category. A new optional `-vN` slot encodes per-tile art variants — visually distinct PNGs the renderer picks per tile from the catalog. Variant 0 is implicit (uses the canonical stem with no suffix); variants 1..N-1 use the literal `v` prefix followed by a non-negative integer.

- Terrain: `terrain-<kind>[-v<variant>][-<frame>].png` where `<kind>` is a value from `TerrainKind`, `<variant>` is a positive integer when the kind opts into per-tile art variants (the canonical sprite omits the slot), and `<frame>` is a non-negative integer when the sprite is animated.
- Terrain transition: `terrain-<upper>-<lower>-t<mask>[-<season>][-<frame>].png` where `<upper>` and `<lower>` are `TerrainKind` values forming a declared transition pair (`grass`/`beach`, `beach`/`water`), `<mask>` is an integer 1–14 whose bits mark the corners carrying `<upper>` (N=1, E=2, S=4, W=8), `<season>` is `autumn` or `winter` for the seasonal sets of a pair whose upper terrain changes with the season, and `<frame>` is a non-negative integer when the tile is animated. Transition tiles do NOT opt into the variant slot.
- Building (land-only): `building-<kind>[-v<variant>][-<state>][-<frame>].png` where `<kind>` is a value from `BuildingKind`, `<variant>` is a positive integer when the kind opts into per-tile art variants, `<state>` is one of `constructing` or `operational` (omitted for the idle baseline sprite), and `<frame>` is a non-negative integer when the sprite is animated.
- Building (shore): `building-<kind>-<orientation>[-<state>][-<frame>].png` where `<orientation>` is one of `n`, `s`, `e`, `w` denoting the cardinal direction of the building's water side, `<state>` and `<frame>` follow the same rules as the land-only building grammar. Shore buildings do NOT opt into the variant slot; orientation already provides the per-tile differentiation. The shore grammar applies exclusively to building kinds that opt into the `shorePlacement` rule (per `buildings-and-construction`).
- Unit (walker): `walker-<facing>-<frame>.png` where `<facing>` is one of `ne`, `nw`, `se`, `sw` and `<frame>` is a non-negative integer. Walkers do NOT opt into the variant slot.
- Unit (ship): `ship-<facing>-<frame>.png` where `<facing>` is one of `n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw` and `<frame>` is a non-negative integer. Ships do NOT opt into the variant slot.

The slot order for terrain and land-only buildings is fixed: `<kind>` → optional `<variant>` → optional `<state>` (buildings only) → optional `<frame>`. Variant slots SHALL never collide with frame digits because the variant slot is literally `v<digit>` whereas the frame slot is a bare digit. The transition slot is literally `t<digit>` and likewise never collides with a frame.

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

#### Scenario: Transition tile name accepted
- **WHEN** the catalog declares `terrain-beach-water-t9`
- **THEN** name validation passes

#### Scenario: Transition tile with an undeclared pair rejected
- **WHEN** the catalog declares `terrain-grass-water-t3`
- **THEN** name validation fails with reason code `transition_pair_unknown`

#### Scenario: Transition mask out of range rejected
- **WHEN** the catalog declares `terrain-grass-beach-t15`
- **THEN** name validation fails with reason code `transition_mask_out_of_range`

### Requirement: Operational frames share one silhouette

Every building operational frame (`<name>-operational-N`) SHALL keep the base sprite's silhouette: the left, right and bottom edges of its opaque bounding box MUST lie within 2 pixels of the base sprite's. The top edge is exempt, so effects such as chimney smoke may rise above the roof. Frames that IsoKit composites from a declared moving part (sails, wheel) are exempt on the side the part sweeps, because the part's extent changes as it turns; their bottom edge MUST still match. The content gate MUST fail on a frame outside this tolerance with reason `frame_misaligned`. Catalog entries MAY declare `operational = "derived"` to have the pipeline build their operational frames from the base sprite, which satisfies this rule by construction.

#### Scenario: Content gate rejects a shifted operational frame

- **WHEN** the content gate compares `building-sawmill-operational-0.png`, whose building sits 6 pixels left of the base sprite's, against `building-sawmill.png`
- **THEN** the gate fails and names `building-sawmill-operational-0.png` with reason `frame_misaligned`

#### Scenario: Content gate accepts smoke above the roof

- **WHEN** an operational frame matches its base sprite except for smoke pixels drawn above the roof line
- **THEN** the gate reports no `frame_misaligned` failure for that frame

#### Scenario: Content gate accepts sails sweeping past the wall

- **WHEN** the sawmill's catalog entry declares a sails moving part on its east side and an operational frame's right edge extends 9 pixels past the base sprite's
- **THEN** the gate reports no `frame_misaligned` failure for that frame

### Requirement: Category-atlas folder layout
The asset pipeline SHALL organize sprite PNGs into category atlases under the `Resources/` directory, each implemented as a SpriteKit `.atlas` folder. `Kit.atlas/` holds every art-kit render, which filters linearly; `Buildings.atlas/`, `Units.atlas/` and `Icons.atlas/` hold the nearest-filtered pixel art, goods icons and status badges. SpriteKit applies one filtering mode to a whole atlas page, so no atlas MAY mix the two. A legacy atlas whose last sprite migrates SHALL be removed: `Terrain.atlas/` no longer exists. No sprite PNG SHALL exist under any other path. The legacy `Resources/Sprites/` directory MUST NOT exist.

#### Scenario: Terrain atlas exists
- **WHEN** the repository is inspected
- **THEN** `Resources/Kit.atlas/` contains every `terrain-*.png` referenced by the sprite catalog, and `Resources/Terrain.atlas/` does not exist

#### Scenario: Buildings atlas exists
- **WHEN** the repository is inspected
- **THEN** `Resources/Buildings.atlas/` exists and contains every `building-*.png` of a brief that has not migrated to the art kit

#### Scenario: Units atlas exists
- **WHEN** the repository is inspected
- **THEN** `Resources/Units.atlas/` exists and contains every `walker-*.png` referenced by the sprite catalog

#### Scenario: Legacy sprite directory removed
- **WHEN** the repository is inspected
- **THEN** `Resources/Sprites/` does not exist

### Requirement: Atlas routing by sprite-name prefix
The `SpriteAtlas` type SHALL resolve every sprite name by routing the lookup to the atlas holding it. A sprite whose catalog brief has migrated to the art kit routes to `Kit`; every other sprite routes by its prefix:

| Prefix | Atlas |
|---|---|
| `terrain-` | `Kit` |
| `building-` | `Buildings` |
| `overlay-` | `Buildings` |
| `walker-` | `Units` |
| `ship-` | `Units` |
| `good-` | `Icons` |

The public `SpriteAtlas` API remains unchanged.

#### Scenario: Ship name routes to Units atlas
- **WHEN** `SpriteAtlas.texture(for: "ship-ne-0")` is called
- **THEN** the lookup is performed against `SKTextureAtlas(named: "Units")` and returns a non-nil texture

#### Scenario: Shore-building name routes to Buildings atlas
- **WHEN** `SpriteAtlas.texture(for: "building-port-w-operational-1")` is called
- **THEN** the lookup is performed against `SKTextureAtlas(named: "Buildings")` and returns a non-nil texture

## ADDED Requirements

### Requirement: Atlas PNGs are rendered by the art kit

Every sprite PNG under `Resources/{Kit,Terrain,Buildings,Units,Icons}.atlas/` SHALL be produced by:

- IsoKit, for buildings and units, or
- the SVG generators of capability `iso-art-kit`, for terrain, transitions and goods icons.

Every PNG has an `@1x` file and an `@2x` file with the same stem. No PNG may come from an image-generation API or from the retired `scripts/generate_sprites_ai` pipeline.

#### Scenario: Every atlas PNG has a recipe or an SVG source

- **WHEN** every PNG under the atlases is routed back to its sprite kind
- **THEN** each kind has an IsoKit recipe or an SVG generator entry

#### Scenario: Every atlas PNG has an @2x twin

- **WHEN** the atlases are enumerated
- **THEN** every `<stem>.png` has a `<stem>@2x.png` with exactly twice its width and height

#### Scenario: The generative pipeline is gone

- **WHEN** the repository is inspected after this change archives
- **THEN** `scripts/generate_sprites_ai/`, `Resources/Sprites.style/_sheets/` and `Resources/Sprites.style/master-reference.png` do not exist, and no Makefile target references an image API key

### Requirement: Offline regeneration via make sprites

A `make sprites` target SHALL regenerate atlas PNGs from the IsoKit recipes and the SVG generators, with no network access and no API key. It covers every catalog entry whose `source` is `isokit` or `svg`, which after this change archives is every atlas PNG. `make sprites-verify` SHALL run the IsoKit tolerance check, and then the content gate (`make sprites-content`). In CI, the CityRender2D job SHALL run the content gate on every PR. The job MUST exit non-zero if any content-gate rule fails, printing every failing sprite with its reason code, one per line.

#### Scenario: make sprites runs offline

- **WHEN** `make sprites` runs on a Mac with no network and no `OPENAI_API_KEY`
- **THEN** it exits zero and every atlas PNG is written

#### Scenario: Verification fails on a content defect

- **WHEN** `make sprites-verify` runs against atlases where one frame is fully transparent
- **THEN** the command exits non-zero and prints the empty frame's file name with reason `frame_empty`

### Requirement: Building sprites sit on their footprint

The content gate SHALL check every building base sprite (`building-<kind>.png` and `building-<kind>-<orientation>.png`, excluding roads). The lowest opaque pixel MUST be within 1 pixel of the canvas bottom, where the renderer anchors the footprint's bottom vertex. Otherwise the gate fails with reason `not_grounded`. No outline colour is required.

#### Scenario: Content gate rejects a floating rendered building

- **WHEN** the content gate inspects a building base sprite whose lowest opaque pixel is 10 pixels above the canvas bottom
- **THEN** the gate fails for that sprite with reason `not_grounded`

#### Scenario: Rendered buildings without an outline pass

- **WHEN** the content gate inspects an IsoKit building sprite that contains no `#1A1410` pixels and is grounded
- **THEN** the gate reports no failure for that sprite

### Requirement: Terrain sprites fill the diamond with a bleed

Every committed terrain sprite (`terrain-*`, including transition tiles) SHALL cover the whole 64×32 iso diamond with opaque pixels. Its opaque pixels MUST NOT reach more than 1 point (2 pixels @2×) beyond the diamond. This bleed lets neighbouring tiles overlap, so neither exact-diamond stair gaps nor linear filtering leave seams.

#### Scenario: Every committed terrain sprite fills the diamond

- **WHEN** the content gate inspects every PNG in `Resources/Terrain.atlas/`
- **THEN** each one has no transparent pixel inside the diamond and no opaque pixel more than 1 point outside it

#### Scenario: Content gate rejects an under-filled tile

- **WHEN** the content gate inspects a terrain tile with a transparent pixel on its diamond edge
- **THEN** the gate fails and names the tile with reason `terrain_coverage_below_threshold`

### Requirement: Walker sprites are 10×16 points

Every `walker-*` sprite SHALL be 10×16 points (20×32 pixels @2×), with the walker's feet at bottom-centre. Each of the four facings SHALL have four gait frames.

#### Scenario: Walker frames have the walker size

- **WHEN** the content gate inspects `walker-se-0.png` and `walker-se-0@2x.png`
- **THEN** they are 10×16 and 20×32 pixels

#### Scenario: Every facing has four gait frames

- **WHEN** the Units atlas is enumerated
- **THEN** `walker-<facing>-0` … `-3` exist for `ne`, `nw`, `se` and `sw`

## REMOVED Requirements

### Requirement: PNG contents are produced by the style-catalog pipeline
**Reason**: The style-catalog pipeline (PIL procedural sheets and the image API) is retired. Its scenarios demand byte-identical output from `make sprites` and catalog-to-cache mapping, which GPU renders cannot meet.
**Migration**: "Atlas PNGs are rendered by the art kit" replaces it. Atlas names and layout are unchanged; only the producer differs.

### Requirement: Hermetic regeneration via make sprites
**Reason**: Its scenarios are built on the prompt-hash cache, `OPENAI_API_KEY`, and byte-identical offline output, all of which go away.
**Migration**: "Offline regeneration via make sprites" replaces it: still offline and reproducible, now checked within a tolerance by `iso-art-kit` "Offline render within a tolerance".

### Requirement: Content gate runs in sprite verification
**Reason**: It chains the content gate after the byte-identical regen check, which no longer exists.
**Migration**: "Offline regeneration via make sprites" keeps the content gate in `make sprites-verify` and in CI, after the tolerance check.

### Requirement: Building sprites share the outline and sit on their footprint
**Reason**: Pre-rendered 3D buildings have no drawn `#1A1410` outline. The outline rule would reject every new sprite.
**Migration**: "Building sprites sit on their footprint" keeps the grounding rule (`not_grounded`) unchanged.

### Requirement: Terrain sprites fill the iso diamond
**Reason**: Its 90% coverage and 2%-outside limits allow gaps and forbid the 1-point bleed that transition tiles and linear filtering need.
**Migration**: "Terrain sprites fill the diamond with a bleed" replaces it. The failure reason code `terrain_coverage_below_threshold` is kept.
