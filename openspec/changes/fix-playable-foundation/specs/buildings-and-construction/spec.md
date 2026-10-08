## ADDED Requirements

### Requirement: Farm building

The building catalog SHALL include a `farm` kind with a 2×2 footprint, a cost of $60, a material cost of 2 wood, and land-only placement (no shore placement).

#### Scenario: Farm spec exposes its footprint and costs

- **WHEN** the building catalog is queried for `farm`
- **THEN** it reports a 2×2 footprint, a cost of 60, and a material cost of 2 wood

## MODIFIED Requirements

### Requirement: Town center starter inventory

World-gen SHALL seed each island's initial town center `Stockpile` with **6 wood + 4 planks + 2 food**. The starter inventory MUST contribute to the island's aggregate stockpile and MUST be available for deduction on the first placements.

#### Scenario: Fresh-world town center holds starter goods

- **WHEN** a fresh world is generated and the initial town center is inspected
- **THEN** its stockpile reads 6 wood, 4 planks, and 2 food

#### Scenario: Starter goods are part of the island stockpile aggregate

- **WHEN** the island's `IslandSummary.stockpile` is queried on a fresh world
- **THEN** it reflects the town center's 6 wood + 4 planks + 2 food (plus any other goods-buffers on the island)

#### Scenario: First lumberjack placement consumes starter wood

- **WHEN** the player places a lumberjack hut (cost: 2 wood) on a fresh world
- **THEN** placement succeeds and the town center stockpile reads 4 wood + 4 planks + 2 food

#### Scenario: Starter goods afford a lumberjack, a farm, and a house

- **WHEN** on a fresh world the player places a lumberjack hut, then a farm, then a house on buildable land
- **THEN** all three placements are allowed
