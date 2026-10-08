## ADDED Requirements

### Requirement: Merchants consume tools

Merchant houses SHALL consume 1 tools per 8 residents (rounded up) each consumption interval, drawn from goods buffers on their road network like their other needs.

#### Scenario: Merchants consume tools

- **WHEN** the consumption interval elapses for a merchant house with 8 residents next to a buffer holding food, planks, bread and 5 tools
- **THEN** the buffer holds 4 tools

## MODIFIED Requirements

### Requirement: Houses have a population tier

Each house SHALL belong to one of three tiers: peasants (1), citizens (2) and merchants (3). A newly built house starts as peasants. Each tier MUST define a resident capacity and a list of needs:

| Tier | Capacity | Needs |
|---|---|---|
| Peasants | 4 | food |
| Citizens | 6 | food, planks |
| Merchants | 8 | food, planks, bread, tools |

A house's population grows towards its tier's capacity while that tier's needs are met. A house MUST report each need of its current tier as satisfied or unmet.

#### Scenario: New house starts as peasants

- **WHEN** a house finishes construction
- **THEN** its tier is peasants and its capacity is 4

#### Scenario: Peasants grow with food alone

- **WHEN** a peasant house shares a road network with a buffer holding food but no planks, and enough ticks pass for growth
- **THEN** its population increases

#### Scenario: Citizens cannot become merchants without tools

- **WHEN** a full citizen house has food, planks and bread in reach but no tools for 120 ticks
- **THEN** it stays citizens

### Requirement: Houses advance and decline between tiers

A house at full capacity whose next tier's needs are all met for 120 consecutive ticks SHALL move up one tier. A house whose current tier's needs are not all met for 120 consecutive ticks SHALL move down one tier (never below peasants), and its population MUST be reduced to the lower tier's capacity if it exceeds it.

#### Scenario: Full peasant house becomes citizens

- **WHEN** a peasant house with 4 residents shares a road network with a buffer holding food and planks for 120 ticks
- **THEN** the house becomes citizens with capacity 6

#### Scenario: Citizens with bread become merchants

- **WHEN** a citizen house with 6 residents shares a road network with a buffer holding food, planks, bread and tools for 120 ticks
- **THEN** the house becomes merchants with capacity 8

#### Scenario: Merchants without bread decline to citizens

- **WHEN** a merchant house with 8 residents has no bread on its road network for 120 ticks while food and planks are available
- **THEN** the house becomes citizens and its population is at most 6
