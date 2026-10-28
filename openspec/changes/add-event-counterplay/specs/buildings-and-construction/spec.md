## ADDED Requirements

### Requirement: Fire watch

The catalog SHALL include a fire watch: town category, footprint 2×2, cost $60, 2 wood and 2 planks, upkeep 1, build time 20 ticks, no tech. It SHALL answer fires within 8 tiles of its footprint (`seasonal-events`).

#### Scenario: Placing a fire watch

- **WHEN** the player places a fire watch on open, road-adjacent grass with $60, 2 wood and 2 planks on the island
- **THEN** the placement is allowed and a construction site appears

### Requirement: Granary

The catalog SHALL include a granary: town category, footprint 2×2, cost $120, 4 wood and 4 planks, upkeep 1, build time 30 ticks, no tech. It SHALL hold up to 60 of each of food, grain, flour and bread, and no other good.

#### Scenario: A granary refuses planks

- **WHEN** a carrier looks for a store for planks and the only store with room is a granary
- **THEN** the granary is not chosen

### Requirement: Physician and herb garden

The catalog SHALL include a physician (town category, footprint 2×2, cost $90, 2 wood and 3 planks, upkeep 1, build time 25 ticks, no tech, storage 8) that burns 1 herbs every 100 ticks through the fuel rules while a fever is warned or under way. It SHALL also include a herb garden (gather category, footprint 2×2, cost $50, 2 wood, build time 20 ticks, no tech, recipe: 1 herbs every 60 ticks, not a crop).

#### Scenario: Physician idle in a quiet year

- **WHEN** an operational physician holds 4 herbs and no fever is warned or under way for 400 ticks
- **THEN** it still holds 4 herbs

#### Scenario: Physician burns during a warning

- **WHEN** an operational physician holds 4 herbs at a tick whose count is a multiple of 100 while a fever is warned
- **THEN** it holds 3 herbs and is fuelled

### Requirement: Ruins block their plot until cleared

A building that burns down SHALL be replaced by ruins with the same footprint, which record the kind that burnt. Ruins SHALL have no upkeep, no storage and no function, SHALL block placement on their tiles, and SHALL NOT appear in the build palette. Demolishing ruins SHALL clear the tiles at once for 25% of the burnt kind's money cost, rounded up to a multiple of $5 and at least $10. A clear that the treasury cannot pay SHALL be rejected with `notEnoughMoney`.

#### Scenario: Clearing a burnt house

- **WHEN** the player demolishes the ruins of a house with $100 in the treasury
- **THEN** the treasury holds $85 and the tiles are free

#### Scenario: Building on ruins is rejected

- **WHEN** the player places a house over a tile of ruins
- **THEN** the placement is rejected as occupied
