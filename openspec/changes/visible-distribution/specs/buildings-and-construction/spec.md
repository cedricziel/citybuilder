## ADDED Requirements

### Requirement: Marketplace

The building catalog SHALL include a `marketplace` kind: an open market hall, category town, with a 2×2 footprint, a cost of $150, a material cost of 3 wood and 4 planks, upkeep 1, and no research gate. It SHALL be a goods buffer that holds up to 30 of each good, and a market hub with a radius of 18 road tiles, 1 porter per 4 houses served, at most 8 porters, baskets of 10 units and a reserve of 2 consumptions, all from the game data. Porters SHALL leave and return at its road-access tile, the first road tile next to its footprint, like every other carrier.

#### Scenario: Marketplace spec exposes its footprint and costs

- **WHEN** the building catalog is queried for `marketplace`
- **THEN** it reports a 2×2 footprint, a cost of 150 and a material cost of 3 wood and 4 planks, with no research gate

#### Scenario: A marketplace is a hub

- **WHEN** the hub data of `marketplace` is read
- **THEN** it reports a radius of 18, 4 houses per porter, at most 8 porters, 10-unit baskets and a reserve of 2 consumptions

#### Scenario: A finished marketplace stores goods

- **WHEN** a carrier delivers 1 bread to an operational marketplace
- **THEN** the marketplace holds 1 bread
