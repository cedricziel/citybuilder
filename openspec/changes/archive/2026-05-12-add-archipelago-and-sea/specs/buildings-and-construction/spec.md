## ADDED Requirements

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
