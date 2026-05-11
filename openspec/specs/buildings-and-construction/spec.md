# buildings-and-construction Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.

## Requirements
### Requirement: Building catalog
The system SHALL define a catalog of building types available in MVP. The catalog MUST include at minimum: `warehouse`, `lumberjack_hut`, `sawmill`, `house`, `road`, and a base `town_center`. Each building type MUST declare its footprint, cost, terrain rules, and any production/storage behavior.

#### Scenario: Catalog is accessible
- **WHEN** any subsystem requests the building catalog
- **THEN** every MVP building type is enumerated with its full metadata

### Requirement: Footprint placement
Each building SHALL declare a rectangular footprint in tiles (e.g. 2×2, 3×3). Placement MUST validate that every tile under the footprint is build-eligible and unoccupied before construction starts.

#### Scenario: Multi-tile placement validates each tile
- **WHEN** a player attempts to place a 3×3 building where one of the nine tiles is water
- **THEN** placement is rejected and no tiles are claimed

### Requirement: Construction state
A placed building SHALL progress through `planned → constructing → operational` states. Construction MUST take a non-zero number of ticks defined per building. A constructing building MUST NOT produce, store, or satisfy needs.

#### Scenario: Construction completes after declared duration
- **WHEN** a building is placed at tick T with build duration N
- **THEN** at tick T+N the building transitions to `operational`

#### Scenario: Constructing building is non-functional
- **WHEN** a warehouse is in `constructing` state
- **THEN** it accepts no goods and reports zero capacity

### Requirement: Demolition
The player SHALL be able to demolish any operational or constructing building they own. Demolition MUST free all tiles under the footprint and partially refund construction cost per a policy defined in design (zero refund acceptable in v0).

#### Scenario: Demolish frees tiles
- **WHEN** a 2×2 building is demolished
- **THEN** all four tiles become unoccupied and available for new placement

### Requirement: Build cost validation
Placement SHALL be rejected if the player does not have sufficient money to pay the building's full construction cost. Cost MUST be deducted at placement time, not at completion.

#### Scenario: Insufficient funds prevents placement
- **WHEN** the player attempts to place a building costing 500 with a balance of 499
- **THEN** placement is rejected with reason `insufficient_funds` and no money is deducted
