## ADDED Requirements

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
Sprite PNG filenames SHALL conform to one of three grammars based on category:
- Terrain: `terrain-<kind>[-<frame>].png` where `<kind>` is a value from `TerrainKind` and `<frame>` is a non-negative integer when the sprite is animated.
- Building: `building-<kind>[-<state>][-<frame>].png` where `<kind>` is a value from `BuildingKind`, `<state>` is one of `constructing` or `operational` (omitted for the idle baseline sprite), and `<frame>` is a non-negative integer when the sprite is animated.
- Unit: `walker-<facing>-<frame>.png` where `<facing>` is one of `ne`, `nw`, `se`, `sw` and `<frame>` is a non-negative integer.

Filenames MUST be lowercase, hyphen-separated, with no spaces, underscores, or non-ASCII characters.

#### Scenario: Conformant terrain name accepted
- **WHEN** the catalog declares `terrain-water-3`
- **THEN** name validation passes

#### Scenario: Conformant building name accepted
- **WHEN** the catalog declares `building-sawmill-operational-2`
- **THEN** name validation passes

#### Scenario: Conformant building idle baseline accepted
- **WHEN** the catalog declares `building-house` (no state, no frame)
- **THEN** name validation passes

#### Scenario: Conformant walker name accepted
- **WHEN** the catalog declares `walker-ne-1`
- **THEN** name validation passes

#### Scenario: Non-conformant casing rejected
- **WHEN** the catalog declares `Building-Sawmill-operational-0`
- **THEN** name validation fails with reason code `sprite_name_not_lowercase`

#### Scenario: Underscore in name rejected
- **WHEN** the catalog declares `building-town_center` (note: legacy fixture; this MUST be renamed during migration)
- **THEN** name validation fails with reason code `sprite_name_uses_underscore`

#### Scenario: Unknown prefix rejected
- **WHEN** the catalog declares `vehicle-cart-0`
- **THEN** name validation fails with reason code `sprite_name_unknown_prefix`

### Requirement: Atlas routing by sprite-name prefix
The `SpriteAtlas` type SHALL resolve every sprite name by routing the lookup to the category atlas indicated by the name's prefix, per the following table:

| Prefix | Atlas |
|---|---|
| `terrain-` | `Terrain` |
| `building-` | `Buildings` |
| `walker-` | `Units` |

The public `SpriteAtlas` API (`texture(for:)`, `frames(for:)`, and any other accessors defined by the in-flight `sprite-animation` capability) MUST remain unchanged from its pre-migration signature.

#### Scenario: Terrain name routes to Terrain atlas
- **WHEN** `SpriteAtlas.texture(for: "terrain-grass")` is called
- **THEN** the lookup is performed against `SKTextureAtlas(named: "Terrain")` and returns a non-nil texture

#### Scenario: Building name routes to Buildings atlas
- **WHEN** `SpriteAtlas.texture(for: "building-sawmill-operational-0")` is called
- **THEN** the lookup is performed against `SKTextureAtlas(named: "Buildings")` and returns a non-nil texture

#### Scenario: Walker name routes to Units atlas
- **WHEN** `SpriteAtlas.texture(for: "walker-ne-0")` is called
- **THEN** the lookup is performed against `SKTextureAtlas(named: "Units")` and returns a non-nil texture

#### Scenario: Public API surface unchanged
- **WHEN** the post-migration `SpriteAtlas` is compared to its pre-migration source
- **THEN** every public method, property, initializer, and access level is identical (only internal storage differs)

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
