## MODIFIED Requirements

### Requirement: Houses have a population tier

Each house SHALL belong to one of three tiers: peasants (1), citizens (2) and merchants (3). A newly built house starts as peasants. Each tier MUST define a resident capacity and a list of needs:

| Tier | Capacity | Needs |
|---|---|---|
| Peasants | 4 | food |
| Citizens | 6 | food, planks |
| Merchants | 8 | food, planks, bread, tools, cloth |

A house's population grows towards its tier's capacity while that tier's needs are met. A house MUST report each need of its current tier as satisfied or unmet.

#### Scenario: New house starts as peasants

- **WHEN** a house finishes construction
- **THEN** its tier is peasants and its capacity is 4

#### Scenario: Peasants grow with food alone

- **WHEN** a peasant house shares a road network with a buffer holding food but no planks, and enough ticks pass for growth
- **THEN** its population increases

#### Scenario: Citizens cannot become merchants without tools

- **WHEN** a full citizen house has food, planks, bread and cloth in reach but no tools for 120 ticks
- **THEN** it stays citizens

#### Scenario: Citizens cannot become merchants without cloth

- **WHEN** a full citizen house has food, planks, bread and tools in reach but no cloth for 120 ticks
- **THEN** it stays citizens

### Requirement: Houses advance and decline between tiers

A house at full capacity whose next tier's needs are all met for 120 consecutive ticks SHALL move up one tier. A house whose current tier's needs are not all met for 120 consecutive ticks SHALL move down one tier (never below peasants), and its population MUST be reduced to the lower tier's capacity if it exceeds it.

#### Scenario: Full peasant house becomes citizens

- **WHEN** a peasant house with 4 residents shares a road network with a buffer holding food and planks for 120 ticks
- **THEN** the house becomes citizens with capacity 6

#### Scenario: Citizens with bread become merchants

- **WHEN** a citizen house with 6 residents shares a road network with a buffer holding food, planks, bread, tools and cloth for 120 ticks
- **THEN** the house becomes merchants with capacity 8

#### Scenario: Merchants without bread decline to citizens

- **WHEN** a merchant house with 8 residents has no bread on its road network for 120 ticks while food and planks are available
- **THEN** the house becomes citizens and its population is at most 6

#### Scenario: Merchants without cloth decline to citizens

- **WHEN** a merchant house with 8 residents has no cloth on its road network for 120 ticks while its other needs are available
- **THEN** the house becomes citizens and its population is at most 6

### Requirement: Merchants want their culture's luxury

Merchants SHALL need food, planks, bread, tools, cloth and their culture's luxury, eating 1 luxury per 8 residents per consumption interval. Peasants' and citizens' needs SHALL not depend on culture.

#### Scenario: East Asian merchants need tea

- **WHEN** the merchants' needs are read for the East Asian culture
- **THEN** they are food, planks, bread, tools, cloth and tea

#### Scenario: Old saves keep their satisfaction

- **WHEN** a house saved with the old per-good satisfaction keys is loaded
- **THEN** its satisfied goods match the old flags

## ADDED Requirements

### Requirement: Merchants consume cloth

Merchant houses SHALL consume 1 cloth per 8 residents (rounded up) each consumption interval, drawn from goods buffers on their road network like their other needs.

#### Scenario: Merchants consume cloth

- **WHEN** the consumption interval elapses for a merchant house with 8 residents next to a buffer holding food, planks, bread, tools and 5 cloth
- **THEN** the buffer holds 4 cloth

### Requirement: Cloth binds merchants only where it can be made

A player's house SHALL need cloth to advance to merchants, but SHALL be held to cloth when staying or growing as merchants only once Weaving is researched. A rival's house MUST never be held to cloth, to advance or to stay, because no rival can make or buy it. Every other need keeps binding as before. A house still consumes cloth when it can draw it.

#### Scenario: Cloth is exempt from staying a merchant before Weaving

- **WHEN** the binding needs of merchants are read for the player without Weaving researched, and again with it researched
- **THEN** cloth binds advancing in both, and binds staying only with Weaving researched

#### Scenario: Merchants keep their tier without cloth before Weaving

- **WHEN** a merchant house with 8 residents has every need but cloth on its road network for 120 ticks and Weaving is not researched
- **THEN** it stays merchants with 8 residents

#### Scenario: Citizens still need cloth to become merchants before Weaving

- **WHEN** a full citizen house has food, planks, bread, tools and the luxury in reach but no cloth for 120 ticks and Weaving is not researched
- **THEN** it stays citizens

#### Scenario: Rival houses are never held to cloth

- **WHEN** the binding needs of merchants are read for a rival
- **THEN** they include bread and tools and never cloth, whether advancing or staying

#### Scenario: A rival's merchant house keeps its tier without cloth

- **WHEN** a rival's merchant house has every need but cloth in reach for 300 ticks
- **THEN** it stays merchants
