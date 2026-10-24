## ADDED Requirements

### Requirement: Wool and cloth chain

The goods catalog SHALL include `wool` and `cloth`. The production catalog MUST contain:

| Building | Inputs | Outputs | Cycle (ticks) |
|---|---|---|---|
| sheep farm | — | 1 wool | 40 |
| weaver | 2 wool | 1 cloth | 50 |

The sheep farm SHALL be a gather building and the weaver a craft building, both with a 2×2 footprint. Both SHALL be unlocked by the Weaving tech.

#### Scenario: Sheep farm shears wool

- **WHEN** an operational sheep farm runs for 40 ticks
- **THEN** it holds 1 wool

#### Scenario: Weaver weaves cloth from wool

- **WHEN** an operational weaver holds 2 wool and 50 ticks pass
- **THEN** it holds 1 cloth and no wool

#### Scenario: Weaver needs two wool

- **WHEN** an operational weaver holds 1 wool for 60 ticks
- **THEN** it produces no cloth and keeps its wool

#### Scenario: Wool chain building specs are catalogued

- **WHEN** the catalog is read for the sheep farm and the weaver
- **THEN** each has a 2×2 footprint, the sheep farm costs 70 with 3 wood of materials, and the weaver costs 130 with 3 wood and 3 planks of materials

#### Scenario: Cloth reaches a warehouse

- **WHEN** two sheep farms, a weaver and a warehouse share a road network and 900 ticks pass
- **THEN** the warehouse holds cloth made from the sheep farms' wool
