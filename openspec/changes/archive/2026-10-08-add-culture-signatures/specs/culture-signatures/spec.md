## ADDED Requirements

### Requirement: Each culture has a signature building

Each culture SHALL have one signature building tied to it: Northern European the mead hall, Mediterranean the forum, East Asian the temple garden and Middle Eastern the caravanserai. They SHALL need no tech, and a world of another culture SHALL reject them with `wrongCulture`.

#### Scenario: Forum in an Antiquity start

- **WHEN** a new Mediterranean game is created in Antiquity and places a forum
- **THEN** the placement is allowed

#### Scenario: No caravanserai in the north

- **WHEN** a Northern European world places a caravanserai
- **THEN** the placement is rejected as belonging to the Middle Eastern culture

### Requirement: Signature buildings are served their culture's luxury

Each culture signature building SHALL burn 1 of its culture's luxury every 100 ticks through the fuel rules, and SHALL count as served while fuelled. A served building's effect SHALL double; an unserved one SHALL still work at its base rate. Several buildings of the same kind covering one target SHALL count once, at the best rate.

#### Scenario: Forum served wine

- **WHEN** an operational forum holds 2 wine at a tick whose count is a multiple of 100
- **THEN** it holds 1 wine and is served

#### Scenario: Two forums count once

- **WHEN** a merchant house of 8 residents is within 8 tiles of two unserved forums and one tax interval passes with no other population
- **THEN** the tax collected is 40

### Requirement: Mead halls share upkeep

Each upkeep interval, an operational non-house building within 8 tiles of an operational mead hall of the same owner, other than a mead hall, SHALL pay half its catalog upkeep rounded down, or nothing when a covering mead hall is served. Mead halls SHALL pay their own upkeep in full.

#### Scenario: Unserved mead hall

- **WHEN** one upkeep interval passes on Normal with a sawmill and a bakery within 8 tiles of an unserved mead hall and no other buildings
- **THEN** the money balance decreases by 2

#### Scenario: Beer served

- **WHEN** one upkeep interval passes on Normal with a sawmill and a bakery within 8 tiles of a served mead hall and no other buildings
- **THEN** the money balance decreases by 1

### Requirement: Forums raise taxes nearby

Each tax interval, a house within 8 tiles of an operational forum of the same owner SHALL pay 1 extra per resident, or 2 when a covering forum is served.

#### Scenario: Forum tax

- **WHEN** one tax interval passes with a single merchant house of 8 residents within 8 tiles of an unserved forum
- **THEN** the tax collected is 40

#### Scenario: Wine served

- **WHEN** one tax interval passes with a single merchant house of 8 residents within 8 tiles of a served forum
- **THEN** the tax collected is 48

#### Scenario: House out of range

- **WHEN** one tax interval passes with a single merchant house of 8 residents 9 tiles from the only forum
- **THEN** the tax collected is 32

### Requirement: Temple gardens add knowledge

Every 100 ticks, a house at citizens or above within 6 tiles of an operational temple garden of the same owner SHALL add 1 extra knowledge per resident, or 2 when a covering temple garden is served. Peasant houses SHALL add nothing extra.

#### Scenario: Temple knowledge

- **WHEN** 100 ticks pass with a single citizen house of 6 residents within 6 tiles of an unserved temple garden, no library and no current research
- **THEN** knowledge increases by 12

#### Scenario: Tea served

- **WHEN** 100 ticks pass with a single citizen house of 6 residents within 6 tiles of a served temple garden, no library and no current research
- **THEN** knowledge increases by 18

#### Scenario: Peasants don't meditate

- **WHEN** 100 ticks pass with a single peasant house of 4 residents within 6 tiles of a served temple garden, no library and no current research
- **THEN** knowledge does not increase

### Requirement: The caravanserai exports a chosen good

A `setExport` command SHALL set a caravanserai's export good, or clear it; it SHALL be ignored for coffee and for other building kinds. Supply carriers SHALL bring the export good one unit at a time while the caravanserai's stock plus in-flight is below 8 and the goods buffers on its island, excluding caravanserais, hold more than 10 of it.

#### Scenario: Export bread

- **WHEN** the player sets a caravanserai's export good to bread
- **THEN** its export good is bread

#### Scenario: No coffee exports

- **WHEN** the player sets a caravanserai's export good to coffee
- **THEN** its export good is unchanged

#### Scenario: Reserve stays home

- **WHEN** a caravanserai exports food and the warehouses on its island hold 10 food in total
- **THEN** no supply carrier takes food to it

### Requirement: Caravans sell at base price

On ticks whose count is a multiple of 100, after fuel burns, each operational caravanserai holding goods other than coffee SHALL sell up to 4 units, or 8 when served, taking the export good first and then other goods in catalog order. Each unit SHALL earn its good's base price for the caravanserai's owner, the goods SHALL leave the world, and `caravanSold` SHALL be emitted with the goods and revenue.

#### Scenario: Bread caravan

- **WHEN** a caravanserai holding 6 bread and no coffee reaches a tick whose count is a multiple of 100
- **THEN** it holds 2 bread and the tick's events include `caravanSold` with 4 bread and revenue 48

#### Scenario: Coffee doubles the caravan

- **WHEN** a caravanserai holding 8 tools and 2 coffee reaches a tick whose count is a multiple of 100
- **THEN** it holds no tools and 1 coffee, and the caravan earns 240

#### Scenario: Leftovers after changing the export

- **WHEN** a caravanserai exporting tools holds 1 tools and 5 bread and its caravan leaves unserved
- **THEN** it sells 1 tools and 3 bread for $66

### Requirement: Export choice survives saves

A caravanserai's export good SHALL be saved with it, and a building saved without one SHALL load with no export good.

#### Scenario: Older building loads

- **WHEN** a save written before this change is loaded
- **THEN** none of its buildings has an export good
