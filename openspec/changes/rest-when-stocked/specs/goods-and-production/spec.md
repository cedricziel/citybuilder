## ADDED Requirements

### Requirement: Producers rest while the stores hold plenty

A good MAY declare a rest level in its content pack. A producer SHALL rest while every good its recipe makes declares a rest level and its owner's operational town centers, warehouses and ports together hold at least that level of it. A resting producer SHALL be brought no inputs: no supply carrier and no direct delivery from another producer carries a good to it. It keeps the inputs it already holds and SHALL finish the cycle in progress. A producer whose recipe takes no inputs SHALL never rest. The rule applies to every owner and is part of the deterministic simulation.

The shipped packs SHALL give planks, flour, bread, charcoal, iron, tools and every culture's luxury a rest level of 40.

#### Scenario: A sawmill rests on 40 planks

- **WHEN** a player's stores hold 40 planks and 20 wood, and a connected sawmill holds no wood
- **THEN** no carrier brings the sawmill wood

#### Scenario: A sawmill works below the rest level

- **WHEN** a player's stores hold 39 planks and 20 wood, and a connected sawmill holds no wood
- **THEN** a carrier brings the sawmill wood

#### Scenario: A resting producer finishes its cycle

- **WHEN** a sawmill holding 1 wood is part-way through a cycle and the stores reach 40 planks
- **THEN** the sawmill completes that cycle

#### Scenario: Gatherers never rest

- **WHEN** a player's stores hold 40 wood and a lumberjack hut has forest in reach
- **THEN** the hut keeps cutting wood
