## ADDED Requirements

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
