## ADDED Requirements

### Requirement: Rival towns stay deterministic

Two worlds created with the same layout, seed, culture, age, difficulty and rival setting, given the same player commands at the same ticks, SHALL be equal after any number of ticks, rivals included. A world saved and reloaded between a rival's decision and its application SHALL continue identically.

#### Scenario: Replayed rival game

- **WHEN** two Hard archipelago worlds with seed 42 each run 3,000 ticks with no player commands
- **THEN** the worlds are equal and each rival owns more buildings than its town center

#### Scenario: Save between decision and application

- **WHEN** a world is encoded and decoded right after a tick in which a rival enqueued commands, and both copies run 100 more ticks
- **THEN** the copies are equal
