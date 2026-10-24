## ADDED Requirements

### Requirement: Producers rest while the stores hold plenty

A good MAY declare a rest level in its content pack. A producer SHALL rest while every good its recipe makes declares a rest level, its owner's operational town centers, warehouses and ports on the producer's island together hold at least that level of it, and another kind of operational building of the same owner on that island takes one of its inputs, as a recipe input or as fuel. A producer that shares no input with another kind of building keeps working, since resting would free nothing. Stores on other islands do not count, since they never feed this island's construction sites. A resting producer SHALL be brought no inputs: no supply carrier and no direct delivery from another producer carries a good to it. It keeps the inputs it already holds and SHALL finish the cycle in progress. A producer whose recipe takes no inputs SHALL never rest. The rule applies to every owner and is part of the deterministic simulation.

The shipped packs SHALL give planks, flour, bread, charcoal, iron, tools and every culture's luxury a rest level of 40.

#### Scenario: A sawmill rests on 40 planks

- **WHEN** a player's stores hold 40 planks and 20 wood, a charcoal burner on the island also takes wood, and a connected sawmill holds no wood
- **THEN** no carrier brings the sawmill wood

#### Scenario: A sawmill works below the rest level

- **WHEN** a player's stores hold 39 planks and 20 wood, a charcoal burner on the island also takes wood, and a connected sawmill holds no wood
- **THEN** a carrier brings the sawmill wood

#### Scenario: A producer that shares no input keeps working

- **WHEN** a player's stores hold 40 planks and 20 wood, no other kind of building on the island takes wood, and a connected sawmill holds no wood
- **THEN** a carrier brings the sawmill wood

#### Scenario: Supply resumes below the rest level

- **WHEN** a sawmill rests on 40 planks and the stores drop to 39
- **THEN** a carrier brings the sawmill wood again

#### Scenario: An outpost rests only on its own island's stores

- **WHEN** the player's home island stores hold 40 planks, the stores on an outpost island hold none, and a sawmill and a charcoal burner on the outpost hold no wood
- **THEN** a carrier brings the outpost sawmill wood

#### Scenario: Every output must be stocked

- **WHEN** a producer's recipe makes two goods and the stores hold the rest level of only one, or one of its goods declares no rest level
- **THEN** the producer does not rest

#### Scenario: A resting producer finishes its cycle

- **WHEN** a sawmill holding 1 wood is part-way through a cycle and the stores reach 40 planks
- **THEN** the sawmill completes that cycle

#### Scenario: Gatherers never rest

- **WHEN** a player's stores hold 40 wood and a lumberjack hut has forest in reach
- **THEN** the hut keeps cutting wood
