## MODIFIED Requirements

### Requirement: Port acts as a goods buffer
A port SHALL store each catalog good separately, up to the per-good limit its kind declares, like every goods buffer. Storage MUST be queryable per good and in aggregate. The same buffer storage MUST be accessible to carriers from the land side and to ships from the sea side.

#### Scenario: Carrier deposits into port from land
- **WHEN** a carrier walking the road network arrives at a port (road-connected to its land-side tiles) carrying 1 unit of wood
- **THEN** the port's wood stock increases by 1 and the carrier despawns

#### Scenario: Ship deposits into port from sea
- **WHEN** a docked ship executes `.unloadUpTo(wood, 10)` at a port with room for 10 wood and 10 units of wood in its cargo
- **THEN** the port's wood stock increases by 10 and the ship's wood cargo decreases by 10

#### Scenario: Single port stock view across faces
- **WHEN** a port has wood stock 25 after a sea deposit, and a land-side query against the same port runs in the same tick
- **THEN** the land-side query returns wood stock 25

#### Scenario: Port respects buffer capacity on land-side deposit
- **WHEN** a carrier attempts to deposit wood into a port that holds its limit of wood
- **THEN** the deposit is rejected and the carrier behaves identically to a rejected warehouse deposit (returns or routes to another goods-buffer)

#### Scenario: Port respects buffer capacity on sea-side deposit
- **WHEN** a docked ship attempts to `.unloadUpTo(wood, 50)` at a port with room for only 10 more wood
- **THEN** only 10 units transfer and the remaining 40 stay in the ship's cargo
