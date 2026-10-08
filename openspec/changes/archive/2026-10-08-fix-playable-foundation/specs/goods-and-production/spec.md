## ADDED Requirements

### Requirement: Farm produces food

The production catalog SHALL include a recipe for the `farm` building kind with no inputs and an output of 1 `food` every 40 ticks. Food produced by farms MUST flow through the same carrier and warehouse logistics as other goods, so houses can satisfy their food need.

#### Scenario: Farm produces food without inputs

- **WHEN** a farm has been operational for 40 ticks and its output stockpile has room
- **THEN** its output stockpile holds one more food than it did 40 ticks earlier

#### Scenario: Farm food satisfies a connected house

- **WHEN** a farm's food reaches a road-connected warehouse within service range of a house
- **THEN** that house reports its food need as satisfied

### Requirement: Producers draw inputs from goods buffers

A producer whose recipe has inputs SHALL be supplied by carriers. For each input good, when the producer's stock plus the goods already in flight to it is below twice the recipe amount, the simulation MUST dispatch a carrier from a goods buffer that holds the good and shares a road network with the producer. The good leaves the buffer when the carrier departs and enters the producer's stockpile on arrival. A producer MUST NOT have more input carriers in flight than the per-producer carrier cap. Buffers are tried in ascending entity-ID order, and the shortest road path wins.

#### Scenario: Sawmill receives wood from a connected warehouse

- **WHEN** an operational sawmill with no wood shares a road network with a warehouse holding 5 wood, and enough ticks pass for a carrier to travel between them
- **THEN** the sawmill's stockpile holds wood and the warehouse holds less than 5

#### Scenario: No supply without a shared road network

- **WHEN** a sawmill and a warehouse holding wood both touch roads, but the two roads are not connected
- **THEN** no carrier is dispatched and the warehouse keeps its wood

#### Scenario: Input carriers respect the carrier cap

- **WHEN** a sawmill short of wood shares a road network with a warehouse holding 20 wood
- **THEN** at most the per-producer carrier cap of supply carriers are in flight to the sawmill at any tick

## MODIFIED Requirements

### Requirement: Producer behavior
Each producer building SHALL declare its input goods (zero or more), output goods (at least one), and production duration in ticks. Production MUST consume declared inputs from local stockpile and emit declared outputs to local stockpile. A lumberjack hut harvests forest within 2 tiles (Chebyshev distance) of its footprint and clears one such forest tile per cycle, scanning in row-major order.

#### Scenario: Lumberjack produces wood without inputs
- **WHEN** a lumberjack hut is operational and adjacent to a forest tile
- **THEN** every production duration it adds one wood to its local output stockpile and clears one forest tile

#### Scenario: Lumberjack harvests forest two tiles away
- **WHEN** a lumberjack hut is operational, no forest touches its footprint, and a forest tile lies two tiles from its footprint
- **THEN** it keeps producing wood and clears that forest tile

#### Scenario: Lumberjack stalls once its catchment is cleared
- **WHEN** no forest tile lies within 2 tiles of an operational lumberjack hut's footprint
- **THEN** the lumberjack produces no wood

#### Scenario: Sawmill consumes wood to produce planks
- **WHEN** a sawmill is operational and has at least one wood in its input stockpile
- **THEN** every production duration it consumes one wood and produces one plank

#### Scenario: Sawmill stalls without inputs
- **WHEN** a sawmill has zero wood in its input stockpile
- **THEN** no plank is produced this tick and no input is consumed
