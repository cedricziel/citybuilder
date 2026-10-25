## ADDED Requirements

### Requirement: Producers deliver to short consumers

When a producer sends a unit of a good and no waiting construction site needs it, the producer SHALL first look for a short consumer of the good. A short consumer is an operational building of the same owner on the producer's road network whose recipe inputs or fuel include the good, and whose stock of it plus units already on the way is below twice its recipe amount, and whose stockpile has free room for every unit on the way plus one. The producer SHALL send the unit to the short consumer with the shortest road path, with ties going to the lower entity ID. Only when no consumer is short SHALL it send the unit to the nearest goods buffer with room, as before. Construction materials (goods any building costs) and goods a house tier of the producer's owner needs SHALL always go to the nearest goods buffer with room, never straight to a consumer, because building sites and houses draw on storage. Units on the way to a consumer from a producer SHALL count toward that consumer's inbound supply, so it is not also served from storage for the same need.

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

#### Scenario: Construction materials still go to storage

- **WHEN** a lumberjack hut holds 1 wood, and a sawmill on its road network holds no wood
- **THEN** the carrier leaves the lumberjack hut for the nearest goods buffer with room

#### Scenario: Goods houses need still go to storage

- **WHEN** a bakery holds 1 bread, and a monument on its road network holds no bread
- **THEN** the carrier leaves the bakery for the nearest goods buffer with room

#### Scenario: A full consumer is not short

- **WHEN** a bakery holds no flour but its stockpile has no free room
- **THEN** the windmill's carrier leaves for the nearest goods buffer with room

### Requirement: Carried goods go on to storage

A carrier whose destination cannot take everything it carries, because the destination is full or was demolished, SHALL carry the rest on to the nearest operational goods buffer of the same owner with room for all of it, counting the units already on their way there, or, with none, to the nearest with room for any of it. With no such buffer it SHALL carry the rest back to the building the goods came from, if that building still stands and has room. When no building has room, the goods SHALL wait with the carrier while its destination stands, looking again each tick (`per-good-storage`: nothing is lost to a full store), and SHALL be lost, as before, only when the destination is gone. A supply carrier waits at its consumer while that stands. A producer's goods redirected this way SHALL keep occupying one of that producer's carrier slots until they arrive.

#### Scenario: Goods for a demolished consumer go to storage

- **WHEN** a carrier is on its way with flour to a bakery, and the bakery is demolished
- **THEN** the carrier takes the flour to the nearest goods buffer with room

#### Scenario: Goods for a consumer that filled up go to storage

- **WHEN** a carrier arrives with flour at a bakery whose stockpile has no room left
- **THEN** the carrier takes the flour to the nearest goods buffer with room

#### Scenario: Goods for a site that no longer needs them go to storage

- **WHEN** a carrier is on its way with wood to a construction site, and the site is finished or demolished before it arrives
- **THEN** the carrier takes the wood to the nearest goods buffer with room, and the site's delivered materials do not change

#### Scenario: Goods with no storage go back

- **WHEN** a carrier's destination is demolished, its owner has no goods buffer with room, and the building the goods came from has room
- **THEN** the carrier takes the goods back to the building they came from

### Requirement: Handcarts carry long and bulk hauls

A carrier SHALL travel with its owner's vehicle when its road path is at least the haul distance of 12 road tiles and at least the haul minimum load of 3 units is ready for the same destination. The owner's vehicle is the one whose age began most recently by the owner's age: a handcart from the medieval age on, carrying up to 4. Before the first vehicle's age, every haul SHALL go on foot. Ready means the source holds the units and the destination can take them: a goods buffer has room for that good beyond the units already on their way to it, and a consumer is short of them by at least that many and has room for them. A producer's direct delivery to a short consumer is a haul too: on a long road it SHALL go by vehicle when enough is ready, and otherwise on foot with 1 unit, without waiting for a load. A vehicle SHALL carry as many ready units as fit, up to its capacity. On a long haul to storage, a producer SHALL prefer the nearest goods buffer with room for at least the minimum load over a nearer one with room for less. A producer whose haul to storage is that long SHALL wait until a vehicle load is ready rather than send single units on foot, but for no more than the haul's maximum wait of 200 ticks; then it SHALL send what is ready by vehicle. Every other haul SHALL go on foot with 1 unit. The haul distance, minimum load and maximum wait, and each vehicle's age and capacity, SHALL come from the game data. A vehicle SHALL move one road tile per tick, like a walker, and SHALL take one of its producer's carrier slots. Inbound supply SHALL count the units carriers bring, not the carriers. A carrier from a save without a vehicle SHALL load on foot.

#### Scenario: A long haul with enough ready goes by handcart

- **WHEN** a lumberjack hut holds 4 wood and its nearest goods buffer with room lies 15 road tiles away
- **THEN** one handcart leaves with 4 wood

#### Scenario: A long hop to a short consumer goes by handcart

- **WHEN** a grain farm holds 4 grain and a windmill holding no grain lies 15 road tiles away
- **THEN** one handcart leaves the farm for the windmill with 4 grain

#### Scenario: A short haul stays on foot

- **WHEN** a lumberjack hut holds 4 wood and its nearest goods buffer with room lies 5 road tiles away
- **THEN** a carrier leaves on foot with 1 wood

#### Scenario: A long haul to storage waits for a cart load

- **WHEN** a lumberjack hut holds 2 wood and its nearest goods buffer with room lies 15 road tiles away
- **THEN** no carrier leaves until a third wood is ready, and then one handcart leaves with 3

#### Scenario: Goods that wait too long for a cart load go anyway

- **WHEN** a lumberjack hut whose forest is gone has held 2 wood for 200 ticks, and its nearest goods buffer with room lies 15 road tiles away
- **THEN** one handcart leaves with the 2 wood

#### Scenario: A handcart brings only what a consumer is short of

- **WHEN** a goods buffer 15 road tiles from a charcoal burner holds 10 wood, and the burner holds 1 wood and needs 2 at a time
- **THEN** one handcart leaves for the burner with 3 wood

#### Scenario: A consumer short of little gets a walker

- **WHEN** a goods buffer 15 road tiles from a charcoal burner holds 10 wood, and the burner holds 2 wood and needs 2 at a time
- **THEN** a carrier leaves for the burner on foot with 1 wood

#### Scenario: A handcart counts as one of the producer's carriers

- **WHEN** a producer has one handcart and one carrier on foot on the road
- **THEN** it sends no third carrier until one of them arrives

#### Scenario: Carriers walk before the first vehicle's age

- **WHEN** a lumberjack hut in the antiquity holds 4 wood and its nearest goods buffer with room lies 15 road tiles away
- **THEN** a carrier leaves on foot with 1 wood
