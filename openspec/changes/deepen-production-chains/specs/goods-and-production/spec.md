## ADDED Requirements

### Requirement: Grain, flour and bread chain

The goods catalog SHALL include `grain` and `flour`. The production catalog MUST contain:

| Building | Inputs | Outputs | Cycle (ticks) |
|---|---|---|---|
| grain farm | — | 1 grain | 40 |
| windmill | 2 grain | 1 flour | 40 |
| bakery | 1 flour | 1 bread | 50 |

#### Scenario: Windmill grinds grain into flour

- **WHEN** an operational windmill holds 2 grain and 40 ticks pass
- **THEN** it holds 1 flour and no grain

#### Scenario: Bakery bakes bread from flour

- **WHEN** an operational bakery holds 1 flour and 50 ticks pass
- **THEN** it holds 1 bread and no flour

### Requirement: Iron and tools chain

The goods catalog SHALL include `ore`, `charcoal`, `iron` and `tools`. The production catalog MUST contain:

| Building | Inputs | Outputs | Cycle (ticks) |
|---|---|---|---|
| mine | — | 1 ore | 50 |
| charcoal burner | 2 wood | 1 charcoal | 40 |
| smelter | 1 ore, 1 charcoal | 1 iron | 50 |
| toolsmith | 1 iron, 1 planks | 1 tools | 60 |

A producer with several inputs MUST wait until all of them are in its stockpile before a cycle advances.

#### Scenario: Smelter needs both ore and charcoal

- **WHEN** an operational smelter holds 2 ore and no charcoal for 60 ticks
- **THEN** it produces no iron and keeps its ore

#### Scenario: Toolsmith forges tools from iron and planks

- **WHEN** an operational toolsmith holds 1 iron and 1 planks and 60 ticks pass
- **THEN** it holds 1 tools and neither iron nor planks
