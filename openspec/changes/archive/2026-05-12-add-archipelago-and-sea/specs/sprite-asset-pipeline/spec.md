## MODIFIED Requirements

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

## ADDED Requirements

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
