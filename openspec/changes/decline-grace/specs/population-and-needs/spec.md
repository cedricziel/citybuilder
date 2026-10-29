## MODIFIED Requirements

### Requirement: Houses host population
A house building SHALL be capable of hosting a bounded number of population units. Population MUST grow into a house over time when needs are satisfied and decline when needs stay unmet beyond the tier's grace (see "Houses decline only after a grace period").

#### Scenario: House grows when needs met
- **WHEN** a house is operational, road-connected, and all its needs are continuously satisfied for the configured growth interval
- **THEN** its population count increases by one up to its capacity

#### Scenario: House shrinks when needs unmet
- **WHEN** a house has had an unmet need for its grace of consumption intervals and then continuously for the configured decline interval
- **THEN** its population count decreases by one, not below zero

### Requirement: Houses advance and decline between tiers

A house at full capacity whose next tier's needs are all met for 120 consecutive ticks SHALL move up one tier. A house that is past its grace (see "Houses decline only after a grace period") and whose current tier's needs are not all met for 120 consecutive ticks SHALL move down one tier (never below peasants), and its population MUST be reduced to the lower tier's capacity if it exceeds it.

#### Scenario: Full peasant house becomes citizens

- **WHEN** a peasant house with 4 residents shares a road network with a buffer holding food and planks for 120 ticks
- **THEN** the house becomes citizens with capacity 6

#### Scenario: Citizens with bread become merchants

- **WHEN** a citizen house with 6 residents shares a road network with a buffer holding food, planks, bread, tools and cloth for 120 ticks
- **THEN** the house becomes merchants with capacity 8

#### Scenario: Merchants without bread decline to citizens

- **WHEN** a merchant house with 8 residents has no bread on its road network for its grace of consumption intervals and then for 120 ticks while food and planks are available
- **THEN** the house becomes citizens and its population is at most 6

#### Scenario: Merchants without cloth decline to citizens

- **WHEN** a merchant house with 8 residents has no cloth on its road network for its grace of consumption intervals and then for 120 ticks while its other needs are available
- **THEN** the house becomes citizens and its population is at most 6

## ADDED Requirements

### Requirement: Houses decline only after a grace period

A house SHALL count, for each need that binds it, the consumption intervals in a row in which it drew less of that good than it needed. A need that does not bind it (cloth before Weaving, for example) MUST hold no count. A need that is drawn in full at a consumption MUST reset its count. A house is past its grace when any need that binds it has a count of at least the tier's decline grace (`HouseTier.declineGrace`, scaled by difficulty). Until then the house MUST keep its residents and its tier, and it MUST NOT grow while a binding need is unmet. A house with no residents has nothing to count: it is past its grace as soon as a binding need is unmet. A tier change MUST drop the counts of goods the new tier does not need.

#### Scenario: A short need does not decline a house within its grace
- **WHEN** a merchant house with 8 residents is short of tools for one consumption interval fewer than its grace, with its other needs available
- **THEN** it still has 8 residents and is still merchants after the decline interval and the tier change interval have passed

#### Scenario: A house declines once the grace has run out
- **WHEN** a merchant house with 8 residents stays short of tools for its grace of consumption intervals
- **THEN** it loses a resident when the grace runs out, another every 60 ticks, and drops to citizens 120 ticks after

#### Scenario: A recovered need resets the count
- **WHEN** a house short of tools for all but one of its grace's intervals draws tools in full, and is then short of them again for one interval fewer than its grace
- **THEN** it is not past its grace and keeps its residents

#### Scenario: Researching Weaving does not cut the grace short
- **WHEN** a merchant house has been short of cloth for its whole grace before Weaving is researched, and Weaving is then researched with cloth still short
- **THEN** its count for cloth starts at 1 at the next consumption and it keeps its residents and tier

#### Scenario: Growth waits during the grace
- **WHEN** a house below its capacity has an unmet need within its grace
- **THEN** its population does not grow and does not shrink

#### Scenario: An empty house falls at once
- **WHEN** a merchant house with no residents has an unmet need for 120 ticks
- **THEN** it becomes citizens

#### Scenario: Counts of needs the tier does not have are dropped
- **WHEN** a merchant house short of tools drops to citizens
- **THEN** its count for tools is gone and its count for food is unchanged

#### Scenario: A tier states its grace in the pack
- **WHEN** the core pack's tiers are read
- **THEN** each tier's `declineGrace` is the value its `Tier` item declares

#### Scenario: A tier without a grace waits one interval
- **WHEN** a pack declares a tier with no `declineGrace`
- **THEN** the generated tier has a decline grace of 1: a house declines after the first short consumption, as before, except that a good that left its reach between two draws now counts at the next draw instead of at once

#### Scenario: The generator rejects a grace below 1
- **WHEN** a pack declares a tier with `declineGrace: 0`
- **THEN** the generator exits with a failure that names the pack, the tier and the field

#### Scenario: The generator rejects a grace above 254
- **WHEN** a pack declares a tier with `declineGrace: 255`
- **THEN** the generator exits with a failure that names the pack, the tier and the field, because a house counts its short intervals up to 255 and Easy adds one
