## ADDED Requirements

### Requirement: Each age has a signature building

Each age SHALL have one signature building: Antiquity the monument, Medieval the guild hall, Renaissance the gallery, Industrial the steam engine and Modern the power plant. The monument SHALL be available from the start; the others SHALL be unlocked by the era tech that opens their age.

#### Scenario: Renaissance start has three signatures

- **WHEN** a new game is created in the Renaissance
- **THEN** a monument, a guild hall and a gallery can be placed, and placing a steam engine is rejected as locked by Steam Power

#### Scenario: Antiquity start has the monument

- **WHEN** a new game is created in Antiquity
- **THEN** a monument can be placed, and placing a guild hall is rejected as locked by Feudal Order

### Requirement: Signatures keep working in later ages

A signature building SHALL keep its effect after the world moves into a later age.

#### Scenario: Guild hall after Printing Press

- **WHEN** a Medieval world with an operational guild hall and a sawmill 3 tiles from it completes Printing Press
- **THEN** the sawmill still completes a cycle in 20 ticks

### Requirement: Ranges are measured between footprints

A building SHALL be within r tiles of a source when the Chebyshev gap between their footprints is at most r, where touching footprints have a gap of 1. Signature effects SHALL reach only operational buildings of the source's owner.

#### Scenario: Touching footprints

- **WHEN** a sawmill's footprint touches a guild hall's footprint along an edge
- **THEN** their distance is 1

#### Scenario: Just out of range

- **WHEN** a sawmill is 9 tiles from the only guild hall
- **THEN** it completes a cycle in 25 ticks

### Requirement: Workshops

A workshop SHALL be a building whose recipe has at least one input and at least one output. Speed bonuses SHALL apply only to workshops.

#### Scenario: Farms are not workshops

- **WHEN** a farm stands 2 tiles from an operational guild hall
- **THEN** it completes a cycle in 40 ticks

#### Scenario: Smelters are workshops

- **WHEN** the workshop kinds are read
- **THEN** they include the sawmill, bakery, windmill, quern house, charcoal burner, smelter and toolsmith, and exclude the farm, grain farm, lumberjack hut, mine, shipyard and monument

### Requirement: Guild halls speed up workshops

A workshop within 8 tiles of an operational guild hall SHALL gain 1 extra tick of progress on every tick whose tick count is a multiple of 4. Several guild halls SHALL count once.

#### Scenario: Sawmill near a guild hall

- **WHEN** a supplied sawmill stands 3 tiles from an operational guild hall
- **THEN** it completes a cycle in 20 ticks instead of 25

#### Scenario: Two guild halls count once

- **WHEN** a supplied sawmill stands within 8 tiles of two operational guild halls
- **THEN** it completes a cycle in 20 ticks

### Requirement: Fuelled buildings burn fuel on an interval

Steam engines SHALL burn 1 charcoal every 50 ticks and power plants 2 charcoal every 50 ticks, on ticks whose count is a multiple of 50. A burn that finds the full amount in the building's stockpile SHALL withdraw it and mark the building fuelled; a burn that doesn't SHALL withdraw nothing and mark it unfuelled, emitting `fuelRanOut` when it was fuelled before. Supply carriers SHALL keep twice the burn amount on hand. A new building SHALL start unfuelled.

#### Scenario: Engine burns charcoal

- **WHEN** an operational steam engine holds 2 charcoal at a tick whose count is a multiple of 50
- **THEN** it holds 1 charcoal and is fuelled

#### Scenario: Engine runs out

- **WHEN** a fuelled steam engine holds no charcoal at its next burn
- **THEN** it is unfuelled and the tick's events include `fuelRanOut` for it

#### Scenario: Power plant needs two

- **WHEN** an operational power plant holds 1 charcoal at a burn
- **THEN** it still holds 1 charcoal and is unfuelled

### Requirement: Steam engines speed up workshops and smoke houses

A workshop within 6 tiles of a fuelled steam engine SHALL gain 1 extra tick of progress every tick. A house within 4 tiles of a fuelled steam engine SHALL be smoky and have 2 less capacity. An unfuelled engine SHALL have no effect.

#### Scenario: Steam doubles a sawmill

- **WHEN** a supplied sawmill stands 5 tiles from a fuelled steam engine
- **THEN** it completes a cycle in 13 ticks

#### Scenario: Smoky merchants

- **WHEN** a merchant house stands 3 tiles from a fuelled steam engine
- **THEN** its capacity is 6

#### Scenario: Cold engine

- **WHEN** a merchant house stands 3 tiles from an unfuelled steam engine
- **THEN** its capacity is 8

### Requirement: Power plants energise their surroundings

A house within 10 tiles of a fuelled power plant SHALL be energised and have 2 more capacity. A workshop within 10 tiles of a fuelled power plant SHALL gain 1 extra tick of progress on every tick whose count is even. Power plants SHALL not make houses smoky.

#### Scenario: Energised merchants

- **WHEN** a merchant house stands 9 tiles from a fuelled power plant
- **THEN** its capacity is 10

#### Scenario: Smoky and energised

- **WHEN** a merchant house is within 4 tiles of a fuelled steam engine and within 10 tiles of a fuelled power plant
- **THEN** its capacity is 8

#### Scenario: Power plant speeds a sawmill

- **WHEN** a supplied sawmill stands 8 tiles from a fuelled power plant
- **THEN** it completes a cycle in 17 ticks

### Requirement: Speed bonuses of different sources add up

A workshop in range of signature sources of different kinds SHALL gain the extra progress of each kind.

#### Scenario: Steam and electricity

- **WHEN** a supplied sawmill is within 6 tiles of a fuelled steam engine and within 10 tiles of a fuelled power plant
- **THEN** it completes a cycle in 10 ticks

### Requirement: Houses above capacity shrink

A house whose population is above its capacity SHALL lose 1 resident every 60 ticks until it fits, even when its needs are met.

#### Scenario: Smoke drives residents out

- **WHEN** a merchant house with 8 residents and all needs met becomes smoky
- **THEN** it has 7 residents after 60 ticks and 6 after 120 ticks

### Requirement: The monument is a project

An operational monument SHALL take 2 wood, 2 planks and 1 bread per stage, each stage lasting 60 ticks, and SHALL be complete after 25 stages. On completion it SHALL emit `monumentCompleted`, and it SHALL then neither request nor consume goods. Each owner SHALL have at most one monument.

#### Scenario: One stage

- **WHEN** an operational monument at stage 0 holds 2 wood, 2 planks and 1 bread
- **THEN** it is at stage 1 after 60 ticks and holds none of them

#### Scenario: Completion

- **WHEN** a monument at stage 24 completes a stage
- **THEN** it is at stage 25 and the tick's events include `monumentCompleted`

#### Scenario: Finished monument consumes nothing

- **WHEN** a monument at stage 25 holds 2 wood, 2 planks and 1 bread for 120 ticks
- **THEN** it still holds them, is still at stage 25, and no supply carrier is headed to it

#### Scenario: Second monument

- **WHEN** the player places a monument while one is under construction
- **THEN** the placement is rejected as already built

### Requirement: A finished monument raises taxes

While its owner has a completed monument, the owner's summed house tax per interval SHALL be multiplied by 110 and divided by 100, rounded down.

#### Scenario: Monument bonus

- **WHEN** one tax interval passes with a completed monument and a single merchant house of 8 residents
- **THEN** the money balance increases by 35

### Requirement: Gallery commissions inspire houses

A `commission` command on an operational gallery with no running commission SHALL cost $200 and start a commission lasting 1,200 ticks, emitting `commissionStarted`; it SHALL be ignored when a commission is running or the balance is below $200. When the commission runs out it SHALL emit `commissionEnded`. Houses within 8 tiles of a gallery with a running commission SHALL be inspired: with their needs met they grow every 30 ticks instead of 60 and advance a tier after 60 ticks instead of 120.

#### Scenario: Commissioning

- **WHEN** the player commissions art at a gallery with a balance of $500
- **THEN** the balance is $300 and the commission has 1,200 ticks left

#### Scenario: Too poor to commission

- **WHEN** the player commissions art with a balance of $150
- **THEN** the balance is still $150 and no commission runs

#### Scenario: Inspired house grows faster

- **WHEN** a peasant house with 1 resident and food in reach stands 4 tiles from a gallery with a running commission
- **THEN** it has 2 residents after 30 ticks

#### Scenario: Commission ends

- **WHEN** 1,200 ticks pass after a commission starts
- **THEN** the tick's events include `commissionEnded` and houses near the gallery grow every 60 ticks again

### Requirement: Signature state survives saves

Monument stages, fuel state and commission time SHALL be saved with their building, and a building saved without them SHALL load with stage 0, unfuelled and no commission.

#### Scenario: Older building loads

- **WHEN** a version-8 save with a sawmill is loaded
- **THEN** the sawmill has stage 0, is unfuelled and has no commission
