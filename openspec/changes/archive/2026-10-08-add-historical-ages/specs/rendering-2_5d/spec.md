## ADDED Requirements

### Requirement: Houses render in the world's age

A finished house SHALL use the most specific sprite that exists among `building-house[-tierN]-<age>-<culture>`, `building-house[-tierN]-<age>`, `building-house[-tierN]-<culture>` and `building-house[-tierN]`, where the age part is omitted for Medieval and the culture part for Northern European.

#### Scenario: Industrial Mediterranean citizens

- **WHEN** the scene draws a citizens-tier house in an Industrial Mediterranean world
- **THEN** the node's texture name is "building-house-tier2-industrial-mediterranean"

#### Scenario: Medieval names are unchanged

- **WHEN** the scene draws a peasants-tier house in a Medieval Northern European world
- **THEN** the node uses the shared house sprite
