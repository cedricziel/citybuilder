## ADDED Requirements

### Requirement: Bakery building

The building catalog SHALL include a `bakery` kind with a 2×2 footprint, a cost of $90, a material cost of 2 wood and 2 planks, and land-only placement.

#### Scenario: Bakery spec exposes its footprint and costs

- **WHEN** the building catalog is queried for `bakery`
- **THEN** it reports a 2×2 footprint, a cost of 90, and a material cost of 2 wood and 2 planks
