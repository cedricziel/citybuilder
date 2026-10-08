## ADDED Requirements

### Requirement: Merchants need tools

Merchant houses SHALL need `tools` in addition to food, planks and bread, and MUST consume 1 tools per 8 residents (rounded up) each consumption interval.

#### Scenario: Merchants consume tools

- **WHEN** the consumption interval elapses for a merchant house with 8 residents next to a buffer holding food, planks, bread and 5 tools
- **THEN** the buffer holds 4 tools

#### Scenario: Citizens cannot become merchants without tools

- **WHEN** a full citizen house has food, planks and bread in reach but no tools for 120 ticks
- **THEN** it stays citizens
