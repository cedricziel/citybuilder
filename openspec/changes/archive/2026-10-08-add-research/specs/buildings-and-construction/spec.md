## ADDED Requirements

### Requirement: Library building

The building catalog SHALL include a `library` kind with a 2×2 footprint, a cost of $100, a material cost of 2 wood and 4 planks, and land-only placement.

#### Scenario: Library spec exposes its footprint and costs

- **WHEN** the building catalog is queried for `library`
- **THEN** it reports a 2×2 footprint, a cost of 100, and a material cost of 2 wood and 4 planks
