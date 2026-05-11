# goods-and-production Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.

## Requirements
### Requirement: Goods catalog
The system SHALL define a catalog of goods available in MVP, including at minimum `wood`, `planks`, and `food`. Each good MUST have a stable identifier, display name, and stack unit definition.

#### Scenario: Catalog enumerable
- **WHEN** any subsystem requests the goods catalog
- **THEN** every MVP good is returned with its identifier and metadata

### Requirement: Producer behavior
Each producer building SHALL declare its input goods (zero or more), output goods (at least one), and production duration in ticks. Production MUST consume declared inputs from local stockpile and emit declared outputs to local stockpile.

#### Scenario: Lumberjack produces wood without inputs
- **WHEN** a lumberjack hut is operational and adjacent to a forest tile
- **THEN** every production duration it adds one wood to its local output stockpile and clears one forest tile

#### Scenario: Sawmill consumes wood to produce planks
- **WHEN** a sawmill is operational and has at least one wood in its input stockpile
- **THEN** every production duration it consumes one wood and produces one plank

#### Scenario: Sawmill stalls without inputs
- **WHEN** a sawmill has zero wood in its input stockpile
- **THEN** no plank is produced this tick and no input is consumed

### Requirement: Local stockpile capacity
Every producer SHALL have a finite per-good input and output stockpile capacity. Production MUST halt when the output stockpile is full. Carriers MUST pull from output stockpiles to free capacity.

#### Scenario: Full output stockpile halts production
- **WHEN** a lumberjack's wood output stockpile is at capacity
- **THEN** production pauses until carriers reduce the stockpile

### Requirement: Wood → Planks → Houses chain
The simulation SHALL support a complete supply chain where lumberjacks produce wood, sawmills convert wood to planks, and houses consume planks for upkeep/upgrades. Removing any link MUST cause the downstream link to stall.

#### Scenario: Removing all sawmills stalls house upgrades
- **WHEN** all sawmills on the island are demolished
- **THEN** houses requiring planks for upkeep eventually report unmet needs

### Requirement: Deterministic production timing
Production timing SHALL be deterministic with respect to the simulation tick. Two saves loaded with identical state MUST produce identical outputs after identical tick counts.

#### Scenario: Identical state yields identical production
- **WHEN** two simulations load the same save and run N ticks with no input
- **THEN** their final stockpile counts are identical
