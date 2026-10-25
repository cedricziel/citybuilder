## ADDED Requirements

### Requirement: A house running short shows the short icon before it declines

A player house with residents SHALL report a `.runningShort(good, declining:)` building issue while one of the needs that binds it has been short for one or more consumption intervals. The good is the need with the highest count, ties in the order of the tier's needs; `declining` is true once that count has reached the house's grace. The renderer SHALL choose that good's "short" icon for the issue, so the warning shows from the first short interval, before any resident leaves, and stays through the decline. A house with no issue keeps the rule of the first short good in `Good` order, which covers needs that do not bind it.

#### Scenario: A house in its grace reports the need nearest to decline
- **WHEN** a player merchant house with residents has been short of tools for 2 consumption intervals and of bread for 1, with a grace of 3
- **THEN** its building issue is `.runningShort(.tools, declining: false)`

#### Scenario: A house past its grace says it is declining
- **WHEN** the same house has been short of tools for 3 consumption intervals
- **THEN** its building issue is `.runningShort(.tools, declining: true)`

#### Scenario: A running-short issue shows the good's short icon
- **WHEN** a player house's issue is `.runningShort(.tools, declining: false)`
- **THEN** its status icon is `status-tools-short`

#### Scenario: A road problem comes before a shortage
- **WHEN** a player house with no road beside it is also short of food
- **THEN** its building issue is `.noRoad`

#### Scenario: A need that does not bind raises no warning
- **WHEN** a player merchant house is short of cloth before Weaving is researched
- **THEN** it has no building issue
