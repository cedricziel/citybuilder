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

- **WHEN** the consumption interval elapses for a peasant house with 4 residents holding 2 food, next to a town center holding 10 food
- **THEN** the house holds no food and the town center still holds 10

#### Scenario: Unmet consumption reports the need as unmet

- **WHEN** the consumption interval elapses for a peasant house with 4 residents holding 1 food
- **THEN** it holds no food and its food need is unmet

#### Scenario: Empty house consumes nothing

- **WHEN** the consumption interval elapses for a house with zero residents holding 2 food
- **THEN** it still holds 2 food

#### Scenario: House stock capacity follows consumption

- **WHEN** a merchant house has 8 residents
- **THEN** its stock holds up to 8 food, 2 planks and 4 bread

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

### Requirement: Market hubs gate tier advancement

A house SHALL advance to the next tier only while the hub serving it holds every need of that tier that binds it. A goods buffer on the house's road network that is not a hub serving it SHALL NOT count.

#### Scenario: A warehouse's tools do not make merchants

- **WHEN** a full citizen house is served by a town center holding food, planks and bread but no tools, and a warehouse on its road holds tools, for 120 ticks
- **THEN** it stays citizens

### Requirement: Saves from before market porters keep their houses supplied

A save from before market porters SHALL load with each house holding, for each good it counts as met, one consumption's worth of stock for its residents, so no house comes up short at the first consumption after loading because of the change.

#### Scenario: Loading an older save seeds house stock

- **WHEN** a save from before market porters holds a peasant house with 4 residents whose food need is met
- **THEN** after loading, the house holds 2 food, and its next consumption is not short
