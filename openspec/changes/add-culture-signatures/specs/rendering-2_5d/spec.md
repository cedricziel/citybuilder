## ADDED Requirements

### Requirement: Culture signature rings and animation

Placing or selecting a mead hall or forum SHALL show an 8-tile range ring, and a temple garden a 6-tile ring, highlighting the buildings it affects; the caravanserai SHALL show none. The four culture signature buildings SHALL animate only while served and otherwise show their idle sprite.

#### Scenario: Temple ring

- **WHEN** the player starts placing a temple garden
- **THEN** the scene shows a ring 6 tiles around the ghost footprint and highlights the houses at citizens or above inside it

#### Scenario: Unserved forum is idle

- **WHEN** a snapshot holds an operational, unserved forum
- **THEN** its sprite is `building-forum` and it does not animate
