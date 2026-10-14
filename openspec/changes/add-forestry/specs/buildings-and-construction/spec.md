## ADDED Requirements

### Requirement: Wood producers cost no materials

The lumberjack hut and the forester SHALL have an empty material cost for every owner; only their money cost applies. A player whose island holds no wood SHALL therefore always be able to place a lumberjack hut or a forester when the balance covers its cost.

#### Scenario: Lumberjack hut spec has no material cost
- **WHEN** the building catalog is queried for `lumberjack-hut`
- **THEN** its material cost is empty and its cost is 80

#### Scenario: A town without wood can still build a lumberjack hut
- **WHEN** the player's island holds 0 wood and 0 planks, the balance is $500, and the player places a lumberjack hut beside forest
- **THEN** the placement is allowed, $80 is deducted, and the hut starts construction without waiting for materials

## MODIFIED Requirements

### Requirement: Town center starter inventory

World-gen SHALL seed each island's initial town center `Stockpile` with **6 wood + 5 planks + 2 food**. The starter inventory MUST contribute to the island's aggregate stockpile and MUST be available for deduction on the first placements.

#### Scenario: Fresh-world town center holds starter goods

- **WHEN** a fresh world is generated and the initial town center is inspected
- **THEN** its stockpile reads 6 wood, 5 planks, and 2 food

#### Scenario: Starter goods are part of the island stockpile aggregate

- **WHEN** the island's `IslandSummary.stockpile` is queried on a fresh world
- **THEN** it reflects the town center's 6 wood + 5 planks + 2 food (plus any other goods-buffers on the island)

#### Scenario: First lumberjack placement consumes starter wood

- **WHEN** the player places a lumberjack hut on a fresh world
- **THEN** placement succeeds and consumes no starter wood: the town center stockpile still reads 6 wood + 5 planks + 2 food, because the hut has no material cost

#### Scenario: Starter goods afford a lumberjack, a farm, and a house

- **WHEN** on a fresh world the player places a lumberjack hut, then a farm, then a house on buildable land
- **THEN** all three placements are allowed

#### Scenario: Starter goods never strand the sawmill

- **WHEN** on a fresh world the player places a house and a lumberjack hut, and then tries to place a sawmill
- **THEN** the sawmill placement is allowed, because the town center still holds the one plank it needs
