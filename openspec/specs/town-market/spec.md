# town-market Specification

## Purpose
Lets the player turn money into basic goods and surplus goods into money at the town center, at prices and seasonal limits that keep production, rival trade and caravans the better choice.
## Requirements
### Requirement: Market terms are content

Each good SHALL declare its market terms in its content pack: a seasonal buy limit (units the market sells to the player per season) and a seasonal sell limit (units the market buys from the player per season), each zero when absent. The shipped packs SHALL give wood, planks and food a buy limit of 10, every good a sell limit of 20, and every other good a buy limit of 0.

#### Scenario: Basic goods can be bought
- **WHEN** the market terms of wood, planks and food are read
- **THEN** each has a buy limit of 10 and a sell limit of 20

#### Scenario: Chain goods cannot be bought
- **WHEN** the market terms of bread, tools and every culture luxury are read
- **THEN** each has a buy limit of 0 and a sell limit of 20

### Requirement: Market prices

The market SHALL sell a good to the player at 150% and buy it from the player at 50% of the good's base price, each rounded down and at least $1.

#### Scenario: Town market wood prices
- **WHEN** the market prices of wood are read
- **THEN** the player buys wood at $6 and sells it at $2

#### Scenario: Grain sell price floor
- **WHEN** the market price for selling grain is read
- **THEN** it is $1

#### Scenario: No trade loop makes money
- **WHEN** for every good the market's and the rivals' buy and sell prices and the caravan price are compared
- **THEN** no price at which the player can buy a good is lower than any price at which the player can sell it, so no round trip gains money

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

### Requirement: Selling at the town center

A `marketSell(townCenter, good, quantity)` command SHALL take from the operational player goods buffers on the town center's island, in ascending entity ID order, the least of the requested quantity, the good's sell limit minus the units sold this season, and the units those buffers hold. The goods SHALL leave the world, and the player SHALL earn units × price.

#### Scenario: Selling tools at the town center
- **WHEN** the player's island buffers hold 12 tools and the player asks to sell 5
- **THEN** the buffers hold 7 tools and the balance rises by $75

#### Scenario: Seasonal sell limit
- **WHEN** the player has sold 18 planks this season and asks to sell 10 more
- **THEN** 2 planks are sold

#### Scenario: Selling draws from every buffer on the island
- **WHEN** the town center holds 3 bread, a warehouse on the same island holds 5 bread, and the player asks to sell 6 bread
- **THEN** the buffer with the lower entity ID gives up its bread first and 6 bread are sold in total

#### Scenario: Goods on another island are not sold
- **WHEN** the player's only bread is in a warehouse on a different island from the named town center
- **THEN** a sell order for bread at that town center sells nothing

### Requirement: Seasonal limits reset and persist

Units bought and sold SHALL be counted per player and per good, across all of the player's town centers. The counts SHALL reset to zero when the season changes, and SHALL survive save and load. A save without them SHALL load with zero counts.

#### Scenario: New season resets the limits
- **WHEN** the player bought 10 wood in spring and summer begins
- **THEN** the player can buy 10 wood again

#### Scenario: Two town centers share the limit
- **WHEN** the player has two town centers, bought 10 wood at the first this season, and asks the second for wood
- **THEN** nothing is bought

#### Scenario: Limits survive save and load
- **WHEN** a world where the player bought 6 food this season is saved and loaded
- **THEN** the player can buy 4 more food this season

#### Scenario: Older saves start with fresh limits
- **WHEN** a save written before the market existed is loaded
- **THEN** every good's bought and sold counts this season are 0

### Requirement: Market trades are reported

Every market command that moves at least one unit SHALL emit `marketTraded` with the good, the units, the total money and the direction (bought or sold). The snapshot SHALL carry, for each good with a non-zero limit, its buy and sell prices and the units left to buy and to sell this season. No market command SHALL change anything after the game is over.

#### Scenario: Town market trade event
- **WHEN** the player buys 4 wood for $24
- **THEN** the tick emits `marketTraded(wood, 4, 24, bought)`

#### Scenario: Snapshot shows what is left
- **WHEN** the player has sold 5 iron this season
- **THEN** the snapshot's market lists iron with a sell price of $7 and 15 left to sell

#### Scenario: No trades after game over
- **WHEN** the game is over and a buy command for wood is applied
- **THEN** the balance and stock are unchanged and no `marketTraded` event is emitted

### Requirement: Player trades leave rivals alone

The player's market trades SHALL NOT change any rival's treasury, island stock, prices, offers or market counts. Rivals trade at their own town centers under `rival-towns` / Rival market trades, and those trades SHALL NOT count against the player's limits.

#### Scenario: Market trade leaves rivals alone
- **WHEN** the player sells 20 wood at the market in an archipelago game
- **THEN** every rival's treasury, island stock, offers and market counts are unchanged
