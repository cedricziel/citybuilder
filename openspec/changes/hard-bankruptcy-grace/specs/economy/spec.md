## ADDED Requirements

### Requirement: Early solvency with the market

A town that builds by the rival AI's rules and trades at its own town center's market SHALL stay solvent on Normal. Trading means it buys the wood or planks a step lacks, and sells planks, then wood, above 12 units while its balance is below $150.

#### Scenario: A market-trading town stays solvent on Normal

- **WHEN** such a town plays archipelago seeds 1, 2 and 3 on Normal for 2 years
- **THEN** none of the games ends in bankruptcy

#### Scenario: Market-trading towns stay solvent across seeds

- **WHEN** such a town plays single-island and archipelago seeds 0 to 9 on Normal for 36,000 ticks
- **THEN** none of the games ends in bankruptcy
