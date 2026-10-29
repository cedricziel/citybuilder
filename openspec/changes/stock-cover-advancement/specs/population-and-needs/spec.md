## ADDED Requirements

### Requirement: Advancing needs stock for two draws

A full house SHALL count a need of the next tier as available for advancing only when the buffers on its road network hold, in all, at least two of its draws of that good. One draw is what the house takes at one consumption with its current residents (`HousePopulation.amount`). Houses are visited in entity order. A house that moves up a tier SHALL claim two of its draws of each need that binds the next tier, on its road network, until the end of that tick. A later house's check that tick MUST subtract the claims on its network from the stock. A claim MUST NOT move goods and MUST NOT outlast the tick. A house whose next tier's needs are not all available this way MUST restart its count of ticks towards advancing. The rule applies to player and rival houses alike. It changes nothing about when a need is met for growth, consumption or decline.

#### Scenario: One unit in reach is not enough to advance
- **WHEN** a full citizen house with 6 residents shares a road network with a buffer holding plenty of food, planks, bread and cloth but only 1 tool, for 120 ticks
- **THEN** the house is still citizens

#### Scenario: Stock for two draws lets a house advance
- **WHEN** a full citizen house with 6 residents shares a road network with a buffer holding plenty of food, planks, bread and cloth and 2 tools, for 120 ticks
- **THEN** the house becomes merchants

#### Scenario: Houses advancing in the same tick share the stock
- **WHEN** two full citizen houses with 6 residents each reach 120 ticks of advancing in the same tick, on one road network whose buffers hold plenty of food, planks, bread and cloth but only 3 tools
- **THEN** the house with the lower entity ID becomes merchants, and the other stays citizens and restarts its count

#### Scenario: Claims last one tick
- **WHEN** a house advanced in the previous tick and claimed tools, and no tools have been drawn since
- **THEN** another house on the same road network sees the full tool stock this tick

#### Scenario: Houses on separate road networks do not share claims
- **WHEN** two full citizen houses on two separate road networks, each with its own buffer holding plenty of food, planks, bread and cloth and 2 tools, reach 120 ticks of advancing in the same tick
- **THEN** both houses become merchants
