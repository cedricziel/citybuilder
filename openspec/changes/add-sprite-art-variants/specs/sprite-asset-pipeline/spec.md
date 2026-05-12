## MODIFIED Requirements

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

## ADDED Requirements

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
