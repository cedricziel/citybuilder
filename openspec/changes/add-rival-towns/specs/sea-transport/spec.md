## ADDED Requirements

### Requirement: Ships have an owner

Every ship SHALL have an owner. A ship emitted by a shipyard SHALL have the shipyard's owner. A ship decoded without an owner SHALL be the player's.

#### Scenario: Ship inherits the shipyard's owner

- **WHEN** a player-owned shipyard emits a ship
- **THEN** the ship's owner is the player

#### Scenario: Old ship decodes as the player's

- **WHEN** a ship encoded without an `owner` key is decoded
- **THEN** its owner is the player
