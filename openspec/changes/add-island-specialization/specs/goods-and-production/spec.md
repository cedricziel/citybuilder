## ADDED Requirements

### Requirement: Soil yield scales crop cycles
A crop building's production cycle SHALL be its recipe's cycle × 100 ÷ the soil yield of its crop family on its island, in whole ticks rounded up. At 100% the cycle SHALL be the recipe's. A crop building with a yield of 0% SHALL complete no cycle. Winter, blight and workshop bonuses SHALL apply to its progress as they do today.

#### Scenario: Rich soil grows faster
- **WHEN** a grain farm stands on an island with a grain yield of 125% and has been operational, outside winter, for 32 ticks with room for its output
- **THEN** it has produced 1 grain

#### Scenario: Poor soil grows slower
- **WHEN** a sheep farm stands on an island with a pasture yield of 75% and has been operational, outside winter, for 53 ticks
- **THEN** it has produced no wool, and after 54 ticks it has produced 1

#### Scenario: Full yield keeps the recipe
- **WHEN** a farm on any island has been operational, outside winter, for 40 ticks
- **THEN** it has produced 1 food

### Requirement: Gardens need their climate
Placing a culture garden on an island where it yields 0% SHALL be rejected with `wrongClimate`, naming the climate the garden needs. The check SHALL apply to every owner and SHALL come after the culture check and before the materials check.

#### Scenario: Hops rejected on a tropical island
- **WHEN** a Northern European player with Cultivation researched places a hop garden on their tropical home island in an archipelago game
- **THEN** the placement is rejected with `wrongClimate(temperate)`

#### Scenario: Hops accepted on the colony
- **WHEN** the same player places a hop garden on free grass of their temperate colony island
- **THEN** the placement is accepted

### Requirement: Mines need ore
Placing a mine on an island whose profile has no ore SHALL be rejected with `noOre`. The terrain check SHALL come first, so a mine off the rock is rejected for its terrain.

#### Scenario: Mine rejected without ore
- **WHEN** the player places a mine on a valid mine site of an island whose profile has no ore
- **THEN** the placement is rejected with `noOre`

#### Scenario: Mine accepted with ore
- **WHEN** the player places a mine on a valid mine site of their home island
- **THEN** the placement is accepted
