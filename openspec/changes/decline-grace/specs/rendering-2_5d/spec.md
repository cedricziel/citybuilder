## ADDED Requirements

### Requirement: A house running short shows the short icon before it declines

A player house with residents SHALL report a `.runningShort(good, intervals:, grace:)` building issue while one of the needs that binds it has been short for one or more consumption intervals. The good is the need with the highest count, ties in the order of the tier's needs; `intervals` is that count and `grace` the house's grace, and the issue is declining once the count has reached the grace. The renderer SHALL choose that good's "short" icon for the issue, so the warning shows from the first short interval, before any resident leaves, and stays through the decline. A house with no issue keeps the rule of the first short good in `Good` order, which covers needs that do not bind it.

#### Scenario: A house in its grace reports the need nearest to decline
- **WHEN** a player merchant house with residents has been short of tools for 2 consumption intervals and of bread for 1, with a grace of 3
- **THEN** its building issue is `.runningShort(.tools, intervals: 2, grace: 3)`, not declining

#### Scenario: A house past its grace says it is declining
- **WHEN** the same house has been short of tools for 3 consumption intervals
- **THEN** its building issue is `.runningShort(.tools, intervals: 3, grace: 3)`, declining

#### Scenario: A running-short issue shows the good's short icon
- **WHEN** a player house's issue is `.runningShort(.tools, intervals: 1, grace: 3)`
- **THEN** its status icon is `status-tools-short`

#### Scenario: A tie goes to the first need of the tier
- **WHEN** a player merchant house has been short of bread and of tools for 1 interval each
- **THEN** its building issue names bread

#### Scenario: An empty house raises no warning
- **WHEN** a player merchant house with no residents has a shortage count
- **THEN** it has no building issue

#### Scenario: A road problem comes before a shortage
- **WHEN** a player house with no road beside it is also short of food
- **THEN** its building issue is `.noRoad`

#### Scenario: A need that does not bind raises no warning
- **WHEN** a player merchant house is short of cloth before Weaving is researched
- **THEN** it has no building issue
