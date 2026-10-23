## ADDED Requirements

### Requirement: Following the first steps keeps a Hard start solvent and growing

A scripted player that follows the first-hour guide SHALL stay solvent through the first five in-game years (12,000 ticks) on Hard, on both world layouts, for seeds 0 to 9, and SHALL end those five years with at least 25 residents in its own houses. Following the guide means: it places a farm, a lumberjack hut, a sawmill and 3 houses in that order before anything else, buying the planks or wood a step lacks at the town center market, and afterwards sells surplus there while its balance is below $150. The same scripted player without the guide and without the market SHALL go bankrupt within those five years on Hard seeds 0 and 5 on both layouts, so the check measures what the guide adds.

#### Scenario: Guided Hard start stays solvent and grows

- **WHEN** the scripted player follows the guide on Hard for 12,000 ticks on either layout with a seed from 0 to 9
- **THEN** the game is not over and the player's houses hold at least 25 residents

#### Scenario: Unguided Hard start goes bankrupt

- **WHEN** the same scripted player plays without the guide and without the market on Hard for 12,000 ticks with seed 0 or 5 on either layout
- **THEN** each of those games ends in bankruptcy
