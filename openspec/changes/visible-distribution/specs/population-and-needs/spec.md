## MODIFIED Requirements

### Requirement: Town center supplies house needs

A house's needs SHALL be supplied by market hubs: the town center and marketplaces of the house's owner. A hub serves the houses whose road path to it is at most its hub radius (18 road tiles for the town center and the marketplace, from the game data). A house within reach of several hubs SHALL be served by the nearest, ties going to the lower entity ID. Warehouses and ports SHALL NOT serve houses directly. A need of the house's current tier SHALL count as met while the last consumption of it was not short and the house's stock of it plus the units porters are bringing covers its next consumption; it SHALL turn unmet only when a consumption comes up short or the stock no longer covers the next one. A house with no residents covers its next consumption only with what one resident eats in stock or on the way, so no one moves in before a delivery. A good the current tier does not need SHALL count as met while the hub serving the house holds it.

#### Scenario: Town center food satisfies a connected house

- **WHEN** a house's road path to the player's town center is 10 road tiles, and the town center holds food
- **THEN** the town center serves the house, and a porter brings it food, after which its food need is met

#### Scenario: Unconnected town center does not satisfy needs

- **WHEN** the town center holds food but has no adjacent road
- **THEN** it serves no house, and a road-connected house with no other hub reports its food need as unmet

#### Scenario: Separate road networks do not share goods

- **WHEN** a house touches one road and the town center, holding food, touches a different road that is not connected to the first
- **THEN** the town center does not serve the house, and the house reports its food need as unmet

#### Scenario: A house beyond the radius is not served

- **WHEN** a house's road path to the player's only hub, the town center, is 25 road tiles
- **THEN** no hub serves the house, and no porter brings it anything

#### Scenario: The nearest hub serves a house

- **WHEN** a house lies 12 road tiles from the town center and 4 from a marketplace of the same owner
- **THEN** the marketplace serves the house

#### Scenario: A warehouse does not feed a house

- **WHEN** a house shares a road with a warehouse holding food, and no hub serves the house
- **THEN** the house's food need stays unmet and the warehouse keeps its food

#### Scenario: Stock covers the gap between deliveries

- **WHEN** a peasant house with 4 residents holds 2 food in stock, its last consumption was not short, and no porter is on the way
- **THEN** its food need is met

### Requirement: Houses consume food and planks

Every 100 ticks, each operational house with population SHALL consume its needs from its own house stock: 1 food per 2 residents (rounded up), 1 plank for citizen and merchant houses, and 1 bread per 4 residents (rounded up) for merchant houses. A house SHALL keep a stock of each need of its tier, up to its house-stock capacity: twice the house's consumption of that good per interval and at least 2 (`houseStockConsumptions` and `houseStockMinimum` in the game data). When the stock cannot cover the full amount, the house MUST consume what it holds and report that consumption as short. A house SHALL NOT draw from goods buffers.

#### Scenario: Populated house eats food on the consumption interval

- **WHEN** a citizen house with 4 residents holds 4 food and 2 planks, and the consumption interval elapses
- **THEN** it holds 2 food and 1 plank

#### Scenario: Peasants consume no planks

- **WHEN** the consumption interval elapses for a peasant house with 4 residents holding 2 food and 2 planks
- **THEN** it holds no food and 2 planks

#### Scenario: Merchants eat bread

- **WHEN** the consumption interval elapses for a merchant house with 8 residents holding 8 food, 2 planks and 4 bread
- **THEN** it holds 4 food, 1 plank and 2 bread

#### Scenario: Houses leave the stores alone

- **WHEN** the consumption interval elapses for a peasant house with 4 residents holding 2 food, sharing a road with a warehouse holding 10 food
- **THEN** the house holds no food and the warehouse still holds 10

#### Scenario: Unmet consumption reports the need as unmet

- **WHEN** the consumption interval elapses for a peasant house with 4 residents holding 1 food
- **THEN** it holds no food and its food need is unmet

#### Scenario: Empty house consumes nothing

- **WHEN** the consumption interval elapses for a house with zero residents holding 2 food
- **THEN** it still holds 2 food

#### Scenario: House stock capacity follows consumption

- **WHEN** a merchant house has 8 residents
- **THEN** its stock holds up to 8 food, 2 planks and 4 bread

### Requirement: Houses have a population tier

Each house SHALL belong to one of three tiers: peasants (1), citizens (2) and merchants (3). A newly built house starts as peasants. Each tier MUST define a resident capacity and a list of needs:

| Tier | Capacity | Needs |
|---|---|---|
| Peasants | 4 | food |
| Citizens | 6 | food, planks |
| Merchants | 8 | food, planks, bread, tools |

A house's population grows towards its tier's capacity while that tier's needs are met, as "Town center supplies house needs" defines met. A house MUST report each need of its current tier as satisfied or unmet.

#### Scenario: New house starts as peasants

- **WHEN** a house finishes construction
- **THEN** its tier is peasants and its capacity is 4

#### Scenario: Peasants grow with food alone

- **WHEN** a peasant house holds food in its stock but no planks, and enough ticks pass for growth
- **THEN** its population increases

#### Scenario: Citizens cannot become merchants without tools

- **WHEN** a full citizen house is served by a hub holding food, planks and bread but no tools for 120 ticks
- **THEN** it stays citizens

### Requirement: Houses advance and decline between tiers

A house at full capacity SHALL move up one tier once, for 120 consecutive ticks, the hub serving it holds every need of the next tier that binds it. The stock that counts for advancing is the serving hub's: goods buffers on the house's road network that are not that hub SHALL NOT count, and a house no hub serves cannot advance. Where a rule sets how much stock advancing takes, it measures the serving hub's stock, and houses that advance in the same tick claim from that hub. A house that is past its grace (see "Houses decline only after a grace period") and whose current tier's needs are not all met for 120 consecutive ticks SHALL move down one tier (never below peasants), and its population MUST be reduced to the lower tier's capacity if it exceeds it.

#### Scenario: Full peasant house becomes citizens

- **WHEN** a peasant house with 4 residents is served by a hub holding food and planks for 120 ticks
- **THEN** the house becomes citizens with capacity 6

#### Scenario: Citizens with bread become merchants

- **WHEN** a citizen house with 6 residents is served by a hub holding food, planks, bread, tools, cloth and its culture's luxury for 120 ticks
- **THEN** the house becomes merchants with capacity 8

#### Scenario: Merchants without bread decline to citizens

- **WHEN** a merchant house with 8 residents has no bread in its stock or on the way for its grace of consumption intervals and then for 120 ticks while its other needs are met
- **THEN** the house becomes citizens and its population is at most 6

#### Scenario: A warehouse's tools do not make merchants

- **WHEN** a full citizen house is served by a town center holding every merchant need but tools, and a warehouse on its road holds tools, for 120 ticks
- **THEN** it stays citizens

### Requirement: Merchants consume tools

Merchant houses SHALL consume 1 tools per 8 residents (rounded up) each consumption interval, from their house stock like their other needs.

#### Scenario: Merchants consume tools

- **WHEN** the consumption interval elapses for a merchant house with 8 residents holding 2 tools in its stock
- **THEN** it holds 1 tool

### Requirement: Merchants want their culture's luxury

Merchants SHALL need food, planks, bread, tools and their culture's luxury, eating 1 luxury per 8 residents per consumption interval from their house stock. Peasants' and citizens' needs SHALL not depend on culture.

#### Scenario: East Asian merchants need tea

- **WHEN** the merchants' needs are read for the East Asian culture
- **THEN** they are food, planks, bread, tools and tea

#### Scenario: Old saves keep their satisfaction

- **WHEN** a house saved with the old per-good satisfaction keys is loaded
- **THEN** its satisfied goods match the old flags

## ADDED Requirements

### Requirement: Market porters supply houses

Each operational hub SHALL keep porters: 1, plus 1 per 4 houses it serves, up to 8 (`housesPerPorter` and `maxPorters` in the hub's game data). Every tick, while a hub has fewer porters out than it keeps, it SHALL send one to the served house with the lowest stock ratio. A house's stock ratio is the lowest, over the needs of its tier the hub holds, of its stock plus the units on the way divided by its house-stock capacity; houses whose every such need is full are skipped. Ties SHALL go to the shorter road path, then to the lower entity ID. The porter SHALL carry one basket: for each need of the house's tier the hub holds, in the tier's order of needs, as much as keeps the house within its capacity and at most one consumption, and no more than 10 units in all (`basketUnits`). The basket leaves the hub's stock when the porter sets off. On arrival the porter SHALL put the basket into the house's stock, as far as it has room, and walk back to the hub with what is left, where it puts the rest back. A porter whose house is gone SHALL walk back with the whole basket. Porters SHALL move one road tile per tick and SHALL count as carriers in the world snapshot.

#### Scenario: A hub sends a porter to a house short of food

- **WHEN** the town center holds 10 food and serves one peasant house with 4 residents and no stock
- **THEN** a porter leaves the town center for the house with 2 food

#### Scenario: Porters go to the house that needs them most

- **WHEN** a town center serves two peasant houses, one with half its food stock and one with none
- **THEN** its porter goes first to the house with none

#### Scenario: Porter count follows the houses served

- **WHEN** a town center serves 9 houses that all lack food, and holds plenty of food
- **THEN** it has 3 porters out

#### Scenario: A basket holds at most 10 units

- **WHEN** a hub holding 20 each of food, planks, bread and tools, and nothing else, sends a porter to a merchant house with 8 residents and no stock
- **THEN** the porter carries 4 food, 1 plank, 2 bread and 1 tools

#### Scenario: Porters walk back empty

- **WHEN** a porter has put its whole basket into a house's stock
- **THEN** it walks back to its hub carrying nothing, and only then can the hub send it again

#### Scenario: Leftovers go back to the hub

- **WHEN** a porter brings 2 food to a house that has room for 1
- **THEN** the house takes 1 and the porter returns the other to its hub

### Requirement: Saves from before market porters keep their houses supplied

A save from before market porters SHALL load with each house holding, for each good it counts as met, one consumption's worth of stock for its residents, so no house comes up short at the first consumption after loading because of the change.

#### Scenario: Loading an older save seeds house stock

- **WHEN** a save from before market porters holds a peasant house with 4 residents whose food need is met
- **THEN** after loading, the house holds 2 food, and its next consumption is not short

## REMOVED Requirements

### Requirement: Per-pop needs in MVP

**Reason**: Houses no longer read warehouses for their needs. "Houses consume food and planks", "Town center supplies house needs" and "Market porters supply houses" now define needs, consumption from the house stock and its supply.

**Migration**: None for players; saves seed the house stock ("Saves from before market porters keep their houses supplied").
