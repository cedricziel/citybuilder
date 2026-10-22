## MODIFIED Requirements

### Requirement: Category-atlas folder layout
The asset pipeline SHALL organize sprite PNGs into category atlases under the `Resources/` directory, each implemented as a SpriteKit `.atlas` folder. `Kit.atlas/` holds every art-kit render, which filters linearly. `Buildings.atlas/` and `Icons.atlas/` hold the nearest-filtered pixel art, goods icons and status badges. SpriteKit applies one filtering mode to a whole atlas page, so no atlas MAY mix the two. A legacy atlas SHALL be removed when its last sprite migrates: `Terrain.atlas/` and `Units.atlas/` no longer exist. No sprite PNG SHALL exist under any other path. The legacy `Resources/Sprites/` directory MUST NOT exist.

#### Scenario: Terrain atlas exists
- **WHEN** the repository is inspected
- **THEN** `Resources/Kit.atlas/` contains every `terrain-*.png` referenced by the sprite catalog, and `Resources/Terrain.atlas/` does not exist

#### Scenario: Buildings atlas exists
- **WHEN** the repository is inspected
- **THEN** `Resources/Buildings.atlas/` exists and contains every `building-*.png` of a brief that has not migrated to the art kit

#### Scenario: Units atlas exists
- **WHEN** the repository is inspected
- **THEN** `Resources/Units.atlas/` no longer exists: it is retired, and `Resources/Kit.atlas/` contains every `walker-*`, `carrier-*`, `animal-*` and `ship-*` PNG referenced by the sprite catalog

#### Scenario: Legacy sprite directory removed
- **WHEN** the repository is inspected
- **THEN** `Resources/Sprites/` does not exist

### Requirement: Atlas routing by sprite-name prefix
The `SpriteAtlas` type SHALL resolve every sprite name by routing the lookup to the atlas holding it. A sprite whose catalog brief has migrated to the art kit routes to `Kit`. Every other sprite routes by its prefix:

| Prefix | Atlas |
|---|---|
| `terrain-` | `Kit` |
| `building-` | `Buildings` |
| `overlay-` | `Buildings` |
| `walker-`, `carrier-`, `animal-`, `ship-` | `Kit` |
| `good-` | `Icons` |

The public `SpriteAtlas` API remains unchanged.

#### Scenario: Ship name routes to Units atlas
- **WHEN** `SpriteAtlasRouting.atlasName(for:)` is asked for a `ship-` name whose stem is not kit-rendered
- **THEN** it answers `Kit`, the prefix fallback: the Units atlas is retired

#### Scenario: Shore-building name routes to Buildings atlas
- **WHEN** `SpriteAtlasRouting.atlasName(for:)` is asked for a shore-building name whose facing is not kit-rendered
- **THEN** it answers `Buildings`, the prefix fallback

#### Scenario: Ship name routes to Kit atlas
- **WHEN** `SpriteAtlas.texture(for: "ship-ne-0")` is called
- **THEN** the lookup is performed against `SKTextureAtlas(named: "Kit")` and returns a non-nil texture

#### Scenario: Shore-building name routes to Kit atlas
- **WHEN** `SpriteAtlas.texture(for: "building-port-w-operational-1")` is called
- **THEN** the lookup is performed against `SKTextureAtlas(named: "Kit")` and returns a non-nil texture

## ADDED Requirements

### Requirement: Walker and animal sprite names

Walker and animal sprites SHALL follow these grammars, and every one of them SHALL route to the `Kit` atlas:

- Residents: `walker-[woman-]<facing>-<frame>.png`. Without `woman`, the name is the worker. `<facing>` is one of `ne`, `nw`, `se`, `sw`, and `<frame>` is 0–7.
- Carriers: `carrier-<load>-<facing>-<frame>.png`, where `<load>` is `sack`, `crate`, `barrel` or `logs` (the `CarrierLoad` families of `add-carrier-glide`), with the same facings and frames.
- Grazing animals: `animal-<kind>-<action>-<facing>-<frame>.png`, where `<kind>` is `sheep` or `cow`, `<action>` is `walk` (frames 0–7) or `graze` (frames 0–3), and `<facing>` is as above.
- Hens: `animal-hen-<facing>-<frame>.png`, with frames 0–3.

#### Scenario: Worker and variant names route to Kit

- **WHEN** `SpriteAtlasRouting.atlasName(for:)` is asked for `walker-se-3`, `walker-woman-nw-7` and `carrier-logs-nw-7`
- **THEN** it answers `Kit` for each

#### Scenario: Animal names route to Kit

- **WHEN** `SpriteAtlasRouting.atlasName(for:)` is asked for `animal-sheep-graze-sw-2` and `animal-hen-ne-0`
- **THEN** it answers `Kit` for both

### Requirement: Walker and animal sprite inventory

Walker sprites SHALL be 32×32 points (64×64 pixels @2x), with their feet 5 points above the bottom edge and 12 points from the left edge. No opaque pixel of a figure or its shadow SHALL touch the left, right or bottom edge. Every resident look and carrier load SHALL have 8 frames in each of the four facings. Each animal SHALL have its full frame set in each of the four facings. The sprites SHALL be rendered by IsoKit under the shared light rig, as the buildings are, and ship @1x and @2x. The `Units` atlas is retired: people and ships route to `Kit`.

#### Scenario: Walker frames have the walker size

- **WHEN** the content gate inspects `walker-woman-se-0.png` and `walker-woman-se-0@2x.png`
- **THEN** they are 32×32 and 64×64 pixels, and their left, right and bottom edge rows are transparent

#### Scenario: Every variant and facing has eight gait frames

- **WHEN** `Kit.atlas` is enumerated
- **THEN** `walker-<facing>-0` … `-7`, `walker-woman-<facing>-0` … `-7` and `carrier-<load>-<facing>-0` … `-7` exist for every load and every facing

#### Scenario: A missing gait frame fails the gate

- **WHEN** `carrier-sack-nw-5.png` is missing from a migrated walker atlas
- **THEN** the gate fails with reason `walker_frames_missing` and names that file
