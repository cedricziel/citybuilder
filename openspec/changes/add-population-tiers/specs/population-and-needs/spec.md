## ADDED Requirements

### Requirement: Houses have a population tier

Each house SHALL belong to one of three tiers: peasants (1), citizens (2) and merchants (3). A newly built house starts as peasants. Each tier MUST define a resident capacity and a list of needs:

| Tier | Capacity | Needs |
|---|---|---|
| Peasants | 4 | food |
| Citizens | 6 | food, planks |
| Merchants | 8 | food, planks, bread |

A house's population grows towards its tier's capacity while that tier's needs are met. A house MUST report each need of its current tier as satisfied or unmet.

#### Scenario: New house starts as peasants

- **WHEN** a house finishes construction
- **THEN** its tier is peasants and its capacity is 4

#### Scenario: Peasants grow with food alone

- **WHEN** a peasant house shares a road network with a buffer holding food but no planks, and enough ticks pass for growth
- **THEN** its population increases

### Requirement: Houses advance and decline between tiers

A house at full capacity whose next tier's needs are all met for 120 consecutive ticks SHALL move up one tier. A house whose current tier's needs are not all met for 120 consecutive ticks SHALL move down one tier (never below peasants), and its population MUST be reduced to the lower tier's capacity if it exceeds it.

#### Scenario: Full peasant house becomes citizens

- **WHEN** a peasant house with 4 residents shares a road network with a buffer holding food and planks for 120 ticks
- **THEN** the house becomes citizens with capacity 6

#### Scenario: Citizens with bread become merchants

- **WHEN** a citizen house with 6 residents shares a road network with a buffer holding food, planks and bread for 120 ticks
- **THEN** the house becomes merchants with capacity 8

#### Scenario: Merchants without bread decline to citizens

- **WHEN** a merchant house with 8 residents has no bread on its road network for 120 ticks while food and planks are available
- **THEN** the house becomes citizens and its population is at most 6

### Requirement: Taxes scale with tier

Tax income per resident SHALL be 1 for peasants, 2 for citizens and 4 for merchants, per tax interval.

#### Scenario: Merchant residents pay four times the peasant rate

- **WHEN** one tax interval passes with a single merchant house of 8 residents and no other population
- **THEN** the money balance increases by 32

## MODIFIED Requirements

### Requirement: Houses consume food and planks

Every 100 ticks, each operational house with population SHALL consume, from goods buffers on its road network, 1 food per 2 residents (rounded up). Citizen and merchant houses MUST also consume 1 plank, and merchant houses MUST consume 1 bread per 4 residents (rounded up). Buffers are drained in ascending entity-ID order. When the buffers cannot cover the full amount of a good, the house MUST consume what is available and report that need as unmet until the next consumption succeeds.

#### Scenario: Populated house eats food on the consumption interval

- **WHEN** a citizen house with 4 residents shares a road network with a town center holding 10 food and 10 planks, and the consumption interval elapses
- **THEN** the town center holds 8 food and 9 planks

#### Scenario: Peasants consume no planks

- **WHEN** the consumption interval elapses for a peasant house with 4 residents next to a town center holding 10 food and 10 planks
- **THEN** the town center holds 8 food and 10 planks

#### Scenario: Merchants eat bread

- **WHEN** the consumption interval elapses for a merchant house with 8 residents next to a town center holding 10 food, 10 planks and 10 bread
- **THEN** the town center holds 6 food, 9 planks and 8 bread

#### Scenario: Unmet consumption reports the need as unmet

- **WHEN** the consumption interval elapses for a populated house whose only connected buffer holds no food
- **THEN** the house reports its food need as unmet

#### Scenario: Empty house consumes nothing

- **WHEN** the consumption interval elapses for a house with zero residents
- **THEN** no food or planks leave the connected buffers

### Requirement: Tax generation
Operational houses with population SHALL generate tax income each configured interval, contributing to the player's money balance. The tax rate per population unit MUST depend on the house's tier (see "Taxes scale with tier").

#### Scenario: Populated house produces tax
- **WHEN** a peasant house with population P operates for one tax interval
- **THEN** the money balance increases by P × the peasant tax rate

#### Scenario: Empty house produces no tax
- **WHEN** a house has zero population
- **THEN** no tax is added to the money balance for that house
