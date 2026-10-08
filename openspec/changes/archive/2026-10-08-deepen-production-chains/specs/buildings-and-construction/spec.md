## ADDED Requirements

### Requirement: Chain buildings

The building catalog SHALL include these land buildings, each with a 2×2 footprint:

| Kind | Cost | Material cost |
|---|---|---|
| grain farm | $60 | 2 wood |
| windmill | $110 | 3 wood, 3 planks |
| mine | $120 | 4 wood, 2 planks |
| charcoal burner | $70 | 3 wood |
| smelter | $150 | 4 wood, 4 planks |
| toolsmith | $140 | 2 wood, 4 planks |

#### Scenario: Chain building specs are catalogued

- **WHEN** the building catalog is queried for the windmill
- **THEN** it reports a 2×2 footprint, a cost of 110 and a material cost of 3 wood and 3 planks

### Requirement: Terrain requirement for placement

A building kind MAY declare a required terrain and a minimum number of footprint tiles of that terrain. Placement MUST be rejected with reason `needsTerrain(kind)` when the footprint has fewer tiles of the required terrain. The mine requires at least 2 mountain tiles.

#### Scenario: Mine on grass is rejected

- **WHEN** the player attempts to place a mine whose footprint covers only grass
- **THEN** placement is rejected with `needsTerrain(.mountain)`

#### Scenario: Mine on the mountainside is allowed

- **WHEN** the player attempts to place a mine whose footprint covers 2 mountain tiles and 2 grass tiles, with materials available
- **THEN** placement is allowed
