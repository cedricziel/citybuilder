## ADDED Requirements

### Requirement: Producers deliver to short consumers

When a producer sends a unit of a good and no waiting construction site needs it, the producer SHALL first look for a short consumer of the good. A short consumer is an operational building of the same owner on the producer's road network whose recipe inputs or fuel include the good, and whose stock of it plus units already on the way is below twice its recipe amount. The producer SHALL send the unit to the short consumer with the shortest road path, with ties going to the lower entity ID. Only when no consumer is short SHALL it send the unit to the nearest goods buffer with room, as before. Construction materials (goods any building costs) and goods a house tier of the producer's owner needs SHALL always go to the nearest goods buffer with room, never straight to a consumer, because building sites and houses draw on storage. Units on the way to a consumer from a producer SHALL count toward that consumer's inbound supply, so it is not also served from storage for the same need.

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
