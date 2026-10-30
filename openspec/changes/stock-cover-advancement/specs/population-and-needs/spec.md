## ADDED Requirements

### Requirement: Advancing needs stock for two draws

A full house SHALL count a need that the next tier adds as available for advancing only while the hub serving it holds at least two of the house's draws of that good, net of what other houses claimed there earlier in the same tick. One draw is what the house takes at one consumption with its current residents (`HousePopulation.amount`). A need the house already eats keeps the rule in "Houses advance and decline between tiers": it counts while it is met. Houses are visited in entity order. A house that moves up a tier SHALL claim, at its serving hub, two of its draws of each need that the next tier adds and that binds it, until the end of that tick. A claim MUST NOT move goods and MUST NOT outlast the tick. A house whose next tier's needs are not all available this way MUST restart its count of ticks towards advancing. The rule applies to player and rival houses alike.

#### Scenario: One unit at the hub is not enough to advance
- **WHEN** a full citizen house with 6 residents, with its food and planks met, is served by a hub holding plenty of bread, cloth and its culture's luxury but only 1 tool, for 120 ticks
- **THEN** the house is still citizens

#### Scenario: Stock for two draws lets a house advance
- **WHEN** a full citizen house with 6 residents, with its food and planks met, is served by a hub holding plenty of bread, cloth and its culture's luxury and 2 tools, for 120 ticks
- **THEN** the house becomes merchants

#### Scenario: Houses advancing in the same tick share the hub's stock
- **WHEN** two full citizen houses with 6 residents each, served by the same hub holding plenty of bread, cloth and the luxury but only 3 tools, reach 120 ticks of advancing in the same tick
- **THEN** the house with the lower entity ID becomes merchants, and the other stays citizens and restarts its count

#### Scenario: Claims last one tick
- **WHEN** a house advanced in the previous tick and claimed tools at its hub, and no tools have left the hub since
- **THEN** another house served by that hub sees the full tool stock this tick

#### Scenario: Houses served by different hubs do not share claims
- **WHEN** two full citizen houses served by two different hubs, each holding plenty of bread, cloth and the luxury and 2 tools, reach 120 ticks of advancing in the same tick
- **THEN** both houses become merchants
