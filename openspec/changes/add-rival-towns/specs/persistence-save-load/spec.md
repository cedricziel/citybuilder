## ADDED Requirements

### Requirement: Saves before rivals have none

Loading a version-8 save SHALL migrate it to version 9 with no rivals, and every building and ship in it SHALL be the player's.

#### Scenario: v8 save loads without rivals

- **WHEN** a version-8 archipelago save is loaded
- **THEN** its version is 9, it has no rivals, every building and ship is owned by the player, and the player owns every island
