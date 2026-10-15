## MODIFIED Requirements

### Requirement: Houses have a population tier

Each house SHALL belong to one of the house tiers declared in the content packs. The shipped packs MUST declare three tiers: peasants (1), citizens (2) and merchants (3). A newly built house starts as peasants. Each tier MUST define a resident capacity, a tax per resident, a display name and an ordered list of needs. The shipped values are:

| Tier | Capacity | Needs | Tax per resident | Name |
|---|---|---|---|---|
| Peasants | 4 | food | 1 | Peasants |
| Citizens | 6 | food, planks | 2 | Citizens |
| Merchants | 8 | food, planks, bread, tools | 4 | Merchants |

A house's population grows towards its tier's capacity while that tier's needs are met. A house MUST report each need of its current tier as satisfied or unmet, including needs that a content pack adds to the tier.

#### Scenario: New house starts as peasants

- **WHEN** a house finishes construction
- **THEN** its tier is peasants and its capacity is 4

#### Scenario: Peasants grow with food alone

- **WHEN** a peasant house shares a road network with a buffer holding food but no planks, and enough ticks pass for growth
- **THEN** its population increases

#### Scenario: Citizens cannot become merchants without tools

- **WHEN** a full citizen house has food, planks and bread in reach but no tools for 120 ticks
- **THEN** it stays citizens

#### Scenario: Shipped tiers keep their values

- **WHEN** the house tiers are read
- **THEN** they are peasants, citizens and merchants with raw values 1, 2 and 3, and their capacity, needs in order, tax per resident and display name match the table, and every culture's tier names are unchanged

## ADDED Requirements

### Requirement: Other needs are eaten at the luxury rate

Each consumption interval, a house with population SHALL consume 1 unit per 8 residents (rounded up) of every need of its tier other than food, planks and bread, including needs that a content pack adds. A good its tier does not need MUST NOT be consumed.

#### Scenario: A need without its own rate is eaten one per eight residents

- **WHEN** the per-interval amount of a needed good other than food, planks and bread is read for a house with 9 residents
- **THEN** the amount is 2

#### Scenario: A good the tier does not need is not eaten

- **WHEN** the per-interval amount of tools is read for a citizen house with 6 residents
- **THEN** the amount is 0
