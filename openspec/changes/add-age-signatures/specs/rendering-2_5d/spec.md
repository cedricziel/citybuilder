## ADDED Requirements

### Requirement: Signature range rings

While a signature building kind is being placed or a placed one is selected, the scene SHALL outline the tiles within its range and highlight the buildings it affects: 8 tiles for the guild hall and gallery, 6 tiles (speed) and 4 tiles (smoke) for the steam engine, and 10 tiles for the power plant. The monument SHALL have no ring.

#### Scenario: Guild hall ring

- **WHEN** the player starts placing a guild hall
- **THEN** the scene shows a ring 8 tiles around the ghost footprint and highlights the workshops inside it

### Requirement: Signature sprites follow their state

An unfinished operational monument SHALL show construction frame 0 for stages 0–8, frame 1 for stages 9–16 and frame 2 for stages 17–24, and its operational animation once complete. Steam engines and power plants SHALL animate only while fuelled, and galleries only while a commission runs; otherwise they SHALL show their idle sprite. Smoky houses SHALL be tinted grey.

#### Scenario: Half-built monument

- **WHEN** a snapshot holds an operational monument at stage 12
- **THEN** its sprite is `building-monument-constructing-1`

#### Scenario: Cold engine is idle

- **WHEN** a snapshot holds an operational, unfuelled steam engine
- **THEN** its sprite is `building-steam-engine` and it does not animate
