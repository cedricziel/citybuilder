## ADDED Requirements

### Requirement: Age signature buildings

The catalog SHALL include the monument (3×3, $300, 6 wood and 6 planks, no upkeep), the guild hall (3×3, $250, 4 wood and 6 planks, upkeep 3), the gallery (2×2, $180, 2 wood and 4 planks, upkeep 2), the steam engine (2×2, $220, 2 wood, 4 planks and 2 iron, upkeep 3) and the power plant (3×3, $400, 6 planks and 4 iron, upkeep 6).

#### Scenario: Steam engine spec

- **WHEN** the steam engine spec is read
- **THEN** it has a 2×2 footprint, costs $220 with 2 wood, 4 planks and 2 iron, and has upkeep 3

### Requirement: One monument per city

Placing a monument SHALL be rejected with `alreadyBuilt` while its owner has a monument under construction or operational. After the monument is demolished a new one MAY be placed, starting at stage 0.

#### Scenario: Rebuilding after demolition

- **WHEN** the player demolishes a monument at stage 10 and places a new one
- **THEN** the placement is allowed and the new monument starts at stage 0
