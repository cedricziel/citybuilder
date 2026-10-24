## ADDED Requirements

### Requirement: Producers deliver to short consumers

When a producer sends a unit of a good and no waiting construction site needs it, the producer SHALL first look for a short consumer of the good. A short consumer is an operational building of the same owner on the producer's road network whose recipe inputs or fuel include the good, and whose stock of it plus units already on the way is below twice its recipe amount. The producer SHALL send the unit to the short consumer with the shortest road path, with ties going to the lower entity ID. Only when no consumer is short SHALL it send the unit to the nearest goods buffer with room, as before. Units on the way to a consumer from a producer SHALL count toward that consumer's inbound supply, so it is not also served from storage for the same need.

#### Scenario: Flour goes straight to a short bakery

- **WHEN** a windmill holds 1 flour, and a bakery on its road network holds no flour, with a warehouse between them
- **THEN** a carrier leaves the windmill for the bakery, not for the warehouse

#### Scenario: Output goes to storage when no consumer is short

- **WHEN** a windmill holds 1 flour and the only bakery on its road network already holds 2 flour
- **THEN** a carrier leaves the windmill for the nearest goods buffer with room

#### Scenario: A consumer fed directly gets no extra supply carrier

- **WHEN** a bakery short of flour has a direct delivery on the way that brings it to twice its recipe amount
- **THEN** no supply carrier leaves storage for that bakery's flour

#### Scenario: Ties go to the lower entity ID

- **WHEN** two short bakeries lie at the same road distance from a windmill
- **THEN** the windmill's carrier goes to the bakery with the lower entity ID

### Requirement: Handcarts carry long and bulk hauls

A carrier SHALL travel with a handcart when its road path is at least the cart distance of 12 road tiles and at least the cart minimum load of 3 units is ready for the same destination. Ready means the source holds the units and the destination can take them: a goods buffer has room for them, and a consumer is short of them by at least that many. A handcart SHALL carry as many ready units as fit, up to the cart capacity of 4. A producer whose haul to storage is that long SHALL wait until a cart load is ready rather than send single units on foot. Every other haul SHALL go on foot with 1 unit. The cart distance, minimum load and capacity SHALL come from the game data. A handcart SHALL move one road tile per tick, like a walker, and SHALL take one of its producer's carrier slots. Inbound supply SHALL count the units carriers bring, not the carriers. A carrier from a save without a vehicle SHALL load on foot.

#### Scenario: A long haul with enough ready goes by handcart

- **WHEN** a lumberjack hut holds 4 wood and its nearest goods buffer with room lies 15 road tiles away
- **THEN** one handcart leaves with 4 wood

#### Scenario: A short haul stays on foot

- **WHEN** a lumberjack hut holds 4 wood and its nearest goods buffer with room lies 5 road tiles away
- **THEN** a carrier leaves on foot with 1 wood

#### Scenario: A long haul to storage waits for a cart load

- **WHEN** a lumberjack hut holds 2 wood and its nearest goods buffer with room lies 15 road tiles away
- **THEN** no carrier leaves until a third wood is ready, and then one handcart leaves with 3

#### Scenario: A handcart brings only what a consumer is short of

- **WHEN** a goods buffer 15 road tiles from a charcoal burner holds 10 wood, and the burner holds 1 wood and needs 2 at a time
- **THEN** one handcart leaves for the burner with 3 wood

#### Scenario: A consumer short of little gets a walker

- **WHEN** a goods buffer 15 road tiles from a charcoal burner holds 10 wood, and the burner holds 2 wood and needs 2 at a time
- **THEN** a carrier leaves for the burner on foot with 1 wood

#### Scenario: A handcart counts as one of the producer's carriers

- **WHEN** a producer has one handcart and one carrier on foot on the road
- **THEN** it sends no third carrier until one of them arrives
