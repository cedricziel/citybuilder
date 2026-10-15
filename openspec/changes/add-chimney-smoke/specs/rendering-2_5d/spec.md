## ADDED Requirements

### Requirement: Chimneys smoke

The scene SHALL show smoke rising from the chimney of every operational house with residents, and of every operational bakery, smelter, toolsmith and charcoal burner that has no building issue. An operational brewery with no issue SHALL show steam. Empty houses and buildings with an issue SHALL show neither. Which buildings smoke SHALL be a pure function of the snapshot, and smoke SHALL never change simulation state.

#### Scenario: Inhabited house smokes
- **WHEN** a snapshot holds an operational house with 4 residents and an operational house with none
- **THEN** only the first house has a smoke source

#### Scenario: Idle workshop is cold
- **WHEN** a snapshot holds two operational bakeries, one with missing flour
- **THEN** only the bakery without an issue has a smoke source

#### Scenario: Brewery steams
- **WHEN** a snapshot holds an operational brewery with no issue
- **THEN** its source has the steam style

### Requirement: Ambient effects stay in budget

The scene SHALL draw ambient effects only for buildings in the visible tile range, and SHALL show at most `clamp(Int(24 × zoom), 8, 40)` smoke emitters. Working buildings come first, then those nearest the camera centre. Emitters SHALL be pooled and reused. With Reduce Motion on, ambient emitters SHALL emit at half the birth rate and half the speed.

#### Scenario: Smoke budget follows zoom
- **WHEN** 60 inhabited houses and 2 working bakeries are visible at zoom 0.5
- **THEN** the scene shows 12 smoke emitters, and both bakeries are among them

#### Scenario: Reduce Motion slows smoke
- **WHEN** Reduce Motion is on
- **THEN** a house's smoke emitter has half the birth rate and half the speed it has with Reduce Motion off
