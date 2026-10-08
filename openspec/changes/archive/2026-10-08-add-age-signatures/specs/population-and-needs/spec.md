## ADDED Requirements

### Requirement: House capacity can be modified

A house's capacity SHALL be its tier's capacity, minus 2 when smoky, plus 2 when energised, and never below 1. Growth, the full-capacity condition for advancing a tier and the clamp after declining SHALL use this capacity.

#### Scenario: Smoky peasants

- **WHEN** a peasant house stands 2 tiles from a fuelled steam engine
- **THEN** its capacity is 2

#### Scenario: Energised house is not full at 4

- **WHEN** an energised peasant house has 4 residents and food and planks in reach for 120 ticks
- **THEN** it stays peasants, because its capacity is 6
