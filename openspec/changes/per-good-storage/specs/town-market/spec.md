## MODIFIED Requirements

### Requirement: Buying at the town center

A `marketBuy(townCenter, good, quantity)` command SHALL move into the operational player goods buffers on that player-owned town center's island the least of the requested quantity, the good's buy limit minus the units bought this season, those buffers' room for the good, and the units the player's balance pays for at the market price. The goods SHALL fill these buffers, each up to its room for the good, in this order: the town center; the warehouses, then the ports, whose road network reaches the town center's; then the other warehouses, then the other ports. Within each group, buffers SHALL fill in ascending entity ID order. The player SHALL pay units × price. A command that names a building other than an operational player town center, or a good with a buy limit of 0, SHALL change nothing.

#### Scenario: Buying wood at the town center
- **WHEN** the player with $500 and an empty town center asks to buy 4 wood
- **THEN** the town center gains 4 wood and the balance drops by $24

#### Scenario: Seasonal buy limit
- **WHEN** the player has bought 8 wood this season and asks to buy 5 more
- **THEN** 2 wood is bought

#### Scenario: Full town center
- **WHEN** the player asks to buy 10 food, the town center has room for 3 food and the warehouse on its island holds its limit of food
- **THEN** 3 food is bought

#### Scenario: A full town center buys into a warehouse
- **WHEN** the player asks to buy 10 food, the town center holds its limit of food and a warehouse on the same island has room for food
- **THEN** 10 food is bought and the warehouse holds it

#### Scenario: The town center fills first
- **WHEN** the player asks to buy 10 food, the town center has room for 3 food and a warehouse on the same island has room for food
- **THEN** the town center gains 3 food and the warehouse 7

#### Scenario: Stores the town center's roads reach fill first
- **WHEN** the player asks to buy 10 food, the town center holds its limit of food, and of two warehouses with room for food the one with the lower entity ID has no road to the town center
- **THEN** the warehouse a road connects to the town center gains the 10 food

#### Scenario: Warehouses fill before ports
- **WHEN** the player asks to buy 10 food, the town center holds its limit of food, and a port with room for food has a lower entity ID than a warehouse with room for food
- **THEN** the warehouse gains the 10 food

#### Scenario: Stores on another island stay out of a buy
- **WHEN** the player asks to buy 10 food, the town center and the warehouse beside it hold their limit of food and the player's only warehouse with room for food is on another island
- **THEN** nothing is bought

#### Scenario: Short of money
- **WHEN** the player with $20 asks to buy 10 planks
- **THEN** 1 plank is bought for $12

#### Scenario: Tools are not for sale
- **WHEN** the player asks to buy 1 tool
- **THEN** nothing changes and no `marketTraded` event is emitted
