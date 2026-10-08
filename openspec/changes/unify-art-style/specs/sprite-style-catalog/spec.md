## ADDED Requirements

### Requirement: One procedural register for world sprites

Every catalog entry for a building (`building-*`) or unit (`walker`, `ship`) SHALL declare `source = "procedural"`. The style bible `world.md` MUST contain a "Building register" section that pins footprint geometry, light direction, outline, wall height and cast shadow for all procedural buildings.

#### Scenario: Every building and unit entry is procedural

- **WHEN** the catalog entries under `Resources/Sprites.style/catalog/` whose names start with `building-`, `walker` or `ship` are read
- **THEN** each declares `source = "procedural"` in its front matter

#### Scenario: Style bible pins the building register

- **WHEN** `Resources/Sprites.style/world.md` is read
- **THEN** it has a level-2 section titled "Building register"
