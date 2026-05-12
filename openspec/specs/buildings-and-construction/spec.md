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

### Requirement: Shore-placement rule
The placement validator SHALL provide a `shorePlacement` rule, opt-in per building kind, that permits a building's footprint to cover both land tiles and water tiles. A building kind that opts into `shorePlacement` MUST declare a minimum number of land tiles and a minimum number of water tiles in its footprint; a placement attempt MUST satisfy both minima or be rejected.

#### Scenario: Building without shore-placement rule rejects mixed footprint
- **WHEN** the player attempts to place a building kind that does NOT opt into `shorePlacement` such that its footprint covers any water tile
- **THEN** placement is rejected with reason code `terrain_not_buildable` (existing reason from MVP)

#### Scenario: Shore building rejected when below land minimum
- **WHEN** the player attempts to place a shore-placement building requiring ≥1 land tile, where the footprint covers only water tiles
- **THEN** placement is rejected with reason code `shore_requires_land_tile`

#### Scenario: Shore building rejected when below water minimum
- **WHEN** the player attempts to place a shore-placement building requiring ≥1 water tile, where the footprint covers only land tiles
- **THEN** placement is rejected with reason code `shore_requires_water_tile`

#### Scenario: Shore building accepted when minima satisfied
- **WHEN** the player places a shore-placement building requiring ≥1 land and ≥1 water tile, where the footprint covers at least one of each
- **THEN** placement succeeds and the building records its land-side tiles and water-side tile(s) separately

### Requirement: Per-tile face designation
A shore-placement building SHALL classify each tile of its committed footprint as either a `landFace` tile or a `seaFace` tile, based on the underlying terrain at placement time. Downstream subsystems (road connectivity, ship anchor, goods buffer queries) MAY query the building's face designation.

#### Scenario: Land face used for road adjacency
- **WHEN** road-connectivity is computed for a shore-placement building
- **THEN** only that building's `landFace` tiles are considered for orthogonal road adjacency

#### Scenario: Sea face used for ship anchor
- **WHEN** a shore-placement building exposes a ship anchor (e.g. Port)
- **THEN** the anchor coordinate is drawn from one of the building's `seaFace` tiles

#### Scenario: Face designation persists across save/load
- **WHEN** a world containing a shore-placement building is saved and loaded
- **THEN** the loaded building's land-face and sea-face tile classifications match the saved values
