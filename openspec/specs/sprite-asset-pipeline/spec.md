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
Sprite PNG filenames SHALL conform to one of four grammars based on category:
- Terrain: `terrain-<kind>[-<frame>].png` where `<kind>` is a value from `TerrainKind` and `<frame>` is a non-negative integer when the sprite is animated.
- Building (land-only): `building-<kind>[-<state>][-<frame>].png` where `<kind>` is a value from `BuildingKind`, `<state>` is one of `constructing` or `operational` (omitted for the idle baseline sprite), and `<frame>` is a non-negative integer when the sprite is animated.
- Building (shore): `building-<kind>-<orientation>[-<state>][-<frame>].png` where `<orientation>` is one of `n`, `s`, `e`, `w` denoting the cardinal direction of the building's water side, `<state>` and `<frame>` follow the same rules as the land-only building grammar. The shore grammar applies exclusively to building kinds that opt into the `shorePlacement` rule (per `buildings-and-construction`).
- Unit (walker): `walker-<facing>-<frame>.png` where `<facing>` is one of `ne`, `nw`, `se`, `sw` and `<frame>` is a non-negative integer.
- Unit (ship): `ship-<facing>-<frame>.png` where `<facing>` is one of `n`, `ne`, `e`, `se`, `s`, `sw`, `w`, `nw` and `<frame>` is a non-negative integer.

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
