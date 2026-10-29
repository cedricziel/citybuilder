## ADDED Requirements

### Requirement: Ships leave a wake

Each visible ship SHALL carry a wake emitter at its stern. The stern is opposite its heading, projected to the screen. The emitter's particles SHALL be left in a wake layer above the terrain and below buildings, so the foam stays where it was laid. The emitter SHALL emit only while the ship's position keeps changing, and SHALL stop 0.3 s after its last move. Below zoom 0.5 the foam SHALL live half as long. With Reduce Motion on, the emitter SHALL emit at half the birth rate and half the speed.

#### Scenario: Moving ship lays foam
- **WHEN** a ship's position changes between two snapshots
- **THEN** its wake emitter has a positive birth rate and leaves its particles in the wake layer

#### Scenario: Still ship lays none
- **WHEN** a ship has not moved since it appeared
- **THEN** its wake emitter's birth rate is 0

#### Scenario: Reduce Motion halves the wake
- **WHEN** Reduce Motion is on and a ship moves
- **THEN** its wake emitter has half the birth rate and half the speed it has with Reduce Motion off
