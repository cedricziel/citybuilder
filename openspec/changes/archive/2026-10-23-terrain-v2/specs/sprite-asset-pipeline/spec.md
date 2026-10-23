## ADDED Requirements

### Requirement: Terrain object sprites

Terrain objects SHALL be named `terrain-<kind>-<density>[-<season>][-v<variant>]`:

- `<kind>` is `forest` or `mountain`.
- `<density>` is `sparse`, `medium` or `dense` for forest, and `sparse`, `medium`, `dense` or `peak` for mountain.
- `<season>` is `autumn` or `winter` for forest, and `winter` for mountain.
- `<variant>` is 1 to 3; variant 0 is the name without the slot.

Every name SHALL exist at @1x and @2x in `Resources/Kit.atlas` and filter linearly. Each sprite SHALL be 144 × 132 points with the tile centre 56 points from its left edge and 112 points from its top. It SHALL carry its own ground shadow, and nothing in it may reach below the tile's bottom vertex by more than the shadow's softness.

#### Scenario: Object names route to the Kit atlas

- **WHEN** the routing test resolves `terrain-forest-dense-autumn-v2`
- **THEN** it routes to the Kit atlas with linear filtering, under the stem `terrain-forest-dense-autumn`

#### Scenario: Every object sprite ships

- **WHEN** the content gate checks the Kit atlas
- **THEN** every density, season and variant above exists at both scales

### Requirement: Terrain objects are generated deterministically

`art.flora` and `art.rocks` SHALL generate the object sprites from seeded geometry, ray-cast on the CPU and lit with `art.ground`'s rig, with no network, no GPU and no image model. Two runs SHALL produce byte-identical raw renders. A clump's trees, and an outcrop's stones, SHALL depend only on the density and variant, so each season shows the same trees.

#### Scenario: Tree clumps are repeatable

- **WHEN** a tree clump is rendered twice
- **THEN** both renders are byte-identical

#### Scenario: Seasons keep the same trees

- **WHEN** a clump is rendered in spring and in autumn
- **THEN** its trunks stand at the same positions in both

#### Scenario: Outcrops are repeatable

- **WHEN** a rock outcrop is rendered twice
- **THEN** both renders are byte-identical

### Requirement: Rock is rounded at the rim and craggy inside

`art.rocks` SHALL draw `sparse` and `medium` outcrops as rounded, weathered tors and boulders, and `dense` and `peak` outcrops as angular crags. Every `peak` variant SHALL stand taller than every `medium` one, so a rock region rises to a summit. The stone SHALL read as a neutral warm grey under the warm sun, not pink.

#### Scenario: Crags rise above the rim

- **WHEN** the four `peak` and the four `medium` outcrops are built
- **THEN** the lowest peak is taller than the tallest medium outcrop

### Requirement: Grass variants join every neighbour

`art.ground` SHALL draw 4 grass variants per season. A variant SHALL differ from the shared tile-periodic texture only inside a window that is zero on the tile's edges, so any two variants join without a seam.

#### Scenario: Variants share their edges

- **WHEN** two grass variants are rendered
- **THEN** their texels on every tile edge are identical

### Requirement: Per-tile art variants for grass and buildings
A subset of terrain and land-only building kinds SHALL ship multiple visually distinct sprites under the variant slot of the naming grammar (per the modified `Sprite naming grammar` requirement). The renderer SHALL pick one variant per tile via a deterministic function of the tile coordinate so that the choice is stable across replays, snapshots, and renderer reconciliations of equal `World` values.

Per-kind variant counts SHALL be declared in two `SpriteAtlas` constants — `terrainVariantCounts: [TerrainType: Int]` and `buildingVariantCounts: [BuildingKind: Int]`. A kind absent from its table renders only the canonical sprite (variant 0). The terrain inventory SHALL be `terrainVariantCounts[.grass] = 4`. Forest and mountain have no ground sprite: they draw grass ground with a terrain object on top, and their objects carry their own variants.

Variant selection SHALL be implemented by a pure function `SpriteAtlas.variantIndex(coord:count:)` that takes a `TileCoordinate` and the variant count and returns an integer in `0..<count`. The function SHALL be a deterministic function of its inputs alone, with no dependence on RNG, the live `World`, or any external state.

#### Scenario: Grass ships four art variants
- **WHEN** the sprite catalog is enumerated for the grass terrain kind
- **THEN** four entries are present: `terrain-grass` (variant 0) and `terrain-grass-v1`, `terrain-grass-v2`, `terrain-grass-v3`

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

### Requirement: Renderer picks grass and building variants per tile coord
The `IsoWorldScene` scene factory SHALL resolve the texture for a terrain or land-only building sprite spec via the variant-aware lookup keyed on `spec.coord`. The ghost preview path SHALL use the same lookup keyed on the ghost's target tile so the preview matches what the placed tile will render.

#### Scenario: Placed grass tile picks its variant from its coord
- **WHEN** the snapshot reconciler emits a grass terrain spec at coord `(x, y)`
- **THEN** the renderer node's texture is the grass variant `SpriteAtlas.variantIndex(coord: TileCoordinate(x: x, y: y), count: 4)` selects

#### Scenario: Placed road tile picks its connection sprite
- **WHEN** the snapshot reconciler emits a road building spec at coord `(x, y)` in operational state
- **THEN** the renderer node's texture is the connection sprite for the road's neighbours

#### Scenario: Ghost preview matches placement variant
- **WHEN** the ghost preview is reconciled for a road build at coord `(x, y)`
- **THEN** the ghost node's texture is the same texture the placed tile would receive at coord `(x, y)`

## REMOVED Requirements

### Requirement: Per-tile art variants
**Reason**: Mountain lost its ground sprites (terrain-v2): rock is drawn as outcrop objects over grass, and roads pick connection sprites instead of variants.
**Migration**: See "Per-tile art variants for grass and buildings"; mountain variants live in the outcrop sprites (`terrain-mountain-<density>-v<n>`).

### Requirement: Renderer picks variants per tile coord
**Reason**: The mountain and road scenarios no longer apply: mountain has no ground sprite and roads use connection sprites.
**Migration**: See "Renderer picks grass and building variants per tile coord".
