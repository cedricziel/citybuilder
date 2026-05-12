# port-and-shipyard Specification

## Purpose
TBD - created by archiving change add-archipelago-and-sea. Update Purpose after archive.

## Requirements
### Requirement: Port building kind
The buildings catalog SHALL include a `Port` building kind with a default footprint of 2 tiles × 3 tiles. A port building SHALL be placeable only if its footprint satisfies the shore-placement rule defined in `buildings-and-construction`: at least one tile of the footprint is a buildable land tile, and at least one tile of the footprint is a water tile. The water tile occupied by the port footprint MUST be designated as the port's `shipAnchor` and MUST NOT be navigable by other ships' integration paths (it is reserved dock space).

#### Scenario: Port placed straddling shore
- **WHEN** the player places a port whose footprint covers one column of grass tiles and one column of water tiles
- **THEN** placement succeeds and the port records the water-side tile as its `shipAnchor`

#### Scenario: Port placement on all-land footprint rejected
- **WHEN** the player attempts to place a port whose footprint covers only land tiles
- **THEN** placement is rejected with reason code `port_requires_water_tile`

#### Scenario: Port placement on all-water footprint rejected
- **WHEN** the player attempts to place a port whose footprint covers only water tiles
- **THEN** placement is rejected with reason code `port_requires_land_tile`

### Requirement: Port acts as a goods buffer
A port SHALL store goods of any catalog type up to a declared per-port capacity. Storage MUST be queryable per good and in aggregate. The same buffer storage MUST be accessible to carriers from the land side and to ships from the sea side.

#### Scenario: Carrier deposits into port from land
- **WHEN** a carrier walking the road network arrives at a port (road-connected to its land-side tiles) carrying 1 unit of wood
- **THEN** the port's wood stock increases by 1 and the carrier despawns

#### Scenario: Ship deposits into port from sea
- **WHEN** a docked ship executes `.unloadUpTo(wood, 10)` at a port with sufficient free capacity and 10 units of wood in its cargo
- **THEN** the port's wood stock increases by 10 and the ship's wood cargo decreases by 10

#### Scenario: Single port stock view across faces
- **WHEN** a port has wood stock 25 after a sea deposit, and a land-side query against the same port runs in the same tick
- **THEN** the land-side query returns wood stock 25

#### Scenario: Port respects buffer capacity on land-side deposit
- **WHEN** a carrier attempts to deposit into a port whose buffer is already at capacity
- **THEN** the deposit is rejected and the carrier behaves identically to a rejected warehouse deposit (returns or routes to another goods-buffer)

#### Scenario: Port respects buffer capacity on sea-side deposit
- **WHEN** a docked ship attempts to `.unloadUpTo(wood, 50)` at a port with only 10 units of free buffer capacity
- **THEN** only 10 units transfer and the remaining 40 stay in the ship's cargo

### Requirement: Port road connectivity
A port SHALL be considered "road-connected" if at least one land-side tile of its footprint is orthogonally adjacent to a road tile. Carriers SHALL only deposit at or withdraw from a road-connected port.

#### Scenario: Disconnected port refuses carrier service
- **WHEN** no road tile is orthogonally adjacent to any land-side tile of a port's footprint
- **THEN** the port reports `roadConnected == false` and no carrier targets it

#### Scenario: Adjacent road connects port
- **WHEN** a road tile is placed orthogonally adjacent to a land-side tile of a port
- **THEN** the port reports `roadConnected == true` within the same tick

### Requirement: Ship anchor occupancy
The water tile designated as a port's `shipAnchor` SHALL accept at most one docked ship at a time. A second ship attempting to dock at the same port while another ship occupies the anchor MUST wait in `.sailing` state at a position within `arrivalEpsilon * 4` of the anchor, integrating in place, until the anchor is free.

#### Scenario: Second ship waits for anchor
- **WHEN** ship `A` is `.docked` at port `P` and ship `B` arrives at the waypoint for `P` while `A` is still docked
- **THEN** ship `B` remains `.sailing` and does not enter `.docked` state until `A` leaves the anchor

#### Scenario: Anchor frees on departure
- **WHEN** a docked ship completes its manifest and transitions to `.sailing`
- **THEN** within one tick a waiting second ship may transition to `.docked` at the same anchor

### Requirement: Shipyard building kind
The buildings catalog SHALL include a `Shipyard` building kind with a default footprint of 2 tiles × 3 tiles. A shipyard SHALL satisfy the same shore-placement rule as a port (≥1 land tile, ≥1 water tile). A shipyard SHALL be a producer building: it consumes a configured recipe of input goods (default: 20 wood + 10 planks per ship) and, upon recipe completion, emits a new `Ship` entity at the water-side tile of its footprint.

#### Scenario: Shipyard requires inputs before producing
- **WHEN** a shipyard has only 10 wood in its input stockpile (recipe demands 20) and 10 planks
- **THEN** no ship entity is emitted and the shipyard does not consume the inputs

#### Scenario: Shipyard emits ship on recipe completion
- **WHEN** a shipyard accumulates 20 wood and 10 planks and completes its production duration
- **THEN** the recipe's inputs are consumed and a new `Ship` entity is added to the world at the shipyard's water-side tile, in `.idle` state with empty cargo

#### Scenario: Shipyard emits at most one ship per recipe cycle
- **WHEN** a shipyard completes a recipe at tick `T`
- **THEN** the next ship entity from this shipyard is emitted no earlier than tick `T + recipeDuration`

#### Scenario: Shipyard receives inputs via carriers
- **WHEN** a road-connected shipyard requires wood
- **THEN** the consumer pull behavior from `warehouses-and-logistics` causes a carrier to spawn from the nearest goods-buffer holding wood and deliver to the shipyard

### Requirement: Ship default class
A ship emitted by a shipyard SHALL be of the default ship class with declared cargo capacity (default: 50 units), declared speed (default: `Fixed(0.5)` tiles per tick), and declared `arrivalEpsilon` (default: `Fixed(0.25)` tiles).

#### Scenario: Newly built ship has default capacity
- **WHEN** a shipyard emits a ship
- **THEN** the ship's declared capacity equals the default ship class capacity

#### Scenario: Newly built ship is idle and unassigned
- **WHEN** a shipyard emits a ship
- **THEN** the ship's state is `.idle` and its `routeID` is nil

### Requirement: Port and shipyard demolition
A port or shipyard MAY be demolished by the player. Demolishing a port MUST transition every route referencing the demolished port's `PortID` to `.broken`. Demolishing a shipyard SHALL NOT affect any ship the shipyard previously produced.

#### Scenario: Demolishing port breaks dependent routes
- **WHEN** the player demolishes a port that is referenced by two routes (one each, both `.active`)
- **THEN** within one tick both routes are in `.broken` state and any ships currently sailing them transition to `.returning`

#### Scenario: Demolishing shipyard does not affect existing ships
- **WHEN** the player demolishes a shipyard that previously produced ship `S`
- **THEN** ship `S` continues operating with no state change beyond the loss of the construction building
