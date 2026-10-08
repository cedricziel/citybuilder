## ADDED Requirements

### Requirement: Buildings render in the world's culture

An operational building or upgraded house SHALL use its culture variant sprite (`building-<kind>-<culture>`, `building-house-tier<N>-<culture>`) when the world's culture is not Northern European and the variant exists, and the shared sprite otherwise. Construction stages SHALL use the shared sprites.

#### Scenario: East Asian town center

- **WHEN** the scene draws an operational town center in an East Asian world
- **THEN** the node's texture name is "building-town-center-east-asian"

#### Scenario: Shared fallback

- **WHEN** the scene draws an operational sawmill in an East Asian world
- **THEN** the node uses the shared sawmill sprite

#### Scenario: Construction stays shared

- **WHEN** the scene draws a house under construction in a Middle Eastern world
- **THEN** the node uses the shared construction sprite
