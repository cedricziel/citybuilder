## ADDED Requirements

### Requirement: Following the first steps keeps a Hard start solvent

A scripted player that follows the first-hour guide SHALL stay solvent through the first in-game year (2,400 ticks) on Hard, on both world layouts, for seeds 0 to 9. Following the guide means: it places only houses until it owns 3, it never places a building whose difficulty-scaled upkeep would push one collection's net below zero, and it sells surplus at the town center market while its balance is below $150. The same scripted player without the guide SHALL go bankrupt within that year on at least one of those starts, so the check measures what the guide adds.

#### Scenario: Guided Hard start stays solvent

- **WHEN** the scripted player follows the guide on Hard for 2,400 ticks on either layout with a seed from 0 to 9
- **THEN** the game is not over

#### Scenario: Unguided Hard start goes bankrupt

- **WHEN** the same scripted player plays without the guide and without the market on Hard for 2,400 ticks
- **THEN** at least one of those starts ends in bankruptcy
