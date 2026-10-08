## ADDED Requirements

### Requirement: Merchants want their culture's luxury

Merchants SHALL need food, planks, bread, tools and their culture's luxury, eating 1 luxury per 8 residents per consumption interval. Peasants' and citizens' needs SHALL not depend on culture.

#### Scenario: East Asian merchants need tea

- **WHEN** the merchants' needs are read for the East Asian culture
- **THEN** they are food, planks, bread, tools and tea

#### Scenario: Old saves keep their satisfaction

- **WHEN** a house saved with the old per-good satisfaction keys is loaded
- **THEN** its satisfied goods match the old flags
