## ADDED Requirements

### Requirement: Houses host population
A house building SHALL be capable of hosting a bounded number of population units. Population MUST grow into a house over time when needs are satisfied and decline when needs are unmet.

#### Scenario: House grows when needs met
- **WHEN** a house is operational, road-connected, and all its needs are continuously satisfied for the configured growth interval
- **THEN** its population count increases by one up to its capacity

#### Scenario: House shrinks when needs unmet
- **WHEN** a house has unmet needs continuously for the configured decline interval
- **THEN** its population count decreases by one, not below zero

### Requirement: Per-pop needs in MVP
Each population unit SHALL declare needs from a fixed MVP set: at minimum `housing` (implicit, satisfied by living in a house) and `food`. Houses MUST also require `planks` for upkeep, consumed at a configured rate.

#### Scenario: Food need satisfied by stocked warehouse
- **WHEN** a road-connected warehouse within service range holds food in stock
- **THEN** the house's food need is reported as satisfied

#### Scenario: Plank upkeep consumed over time
- **WHEN** a house has population and the upkeep interval elapses
- **THEN** one plank is consumed from a connected warehouse (or upkeep is reported unmet if none available)

### Requirement: Satisfaction tracking
Each house SHALL expose a per-need satisfaction state (`satisfied` / `unmet`) and an aggregate happiness or satisfaction summary readable by UI and economy systems.

#### Scenario: UI reads satisfaction per house
- **WHEN** the player inspects a house
- **THEN** the inspector shows each need with its current satisfaction state

### Requirement: Tax generation
Operational houses with population SHALL generate tax income each configured interval, contributing to the player's money balance. Tax rate per population unit MUST be a tunable constant.

#### Scenario: Populated house produces tax
- **WHEN** a house with population P operates for one tax interval
- **THEN** the money balance increases by P × tax_rate

#### Scenario: Empty house produces no tax
- **WHEN** a house has zero population
- **THEN** no tax is added to the money balance for that house

### Requirement: Population aggregate
The simulation SHALL expose a total population count across all houses, queryable by the HUD without iterating individual entities at render time.

#### Scenario: HUD reads total population
- **WHEN** the HUD displays the population indicator
- **THEN** the value equals the sum of all house population counts as of the most recent tick snapshot
