## ADDED Requirements

### Requirement: Early solvency with the market

A scripted town SHALL stay solvent on Normal when it trades at its own town center's market. The town follows the rival AI's opening and growth loop and town plan, adds farms, sawmills, lumberjack huts and foresters when its food, planks or wood run low, and keeps $50 after every step. Trading means it buys the wood or planks a step lacks, and sells planks, then wood, above 12 units while its balance is below $150.

#### Scenario: Market-trading towns stay solvent across seeds

- **WHEN** such a town plays single-island and archipelago seeds 0 to 9 on Normal for 36,000 ticks
- **THEN** none of the games ends in bankruptcy

#### Scenario: Without the market the same towns go bankrupt

- **WHEN** such a town plays archipelago seeds 2, 6, 9 and 21 on Normal for 4,000 ticks without trading at its market
- **THEN** every game ends in bankruptcy
