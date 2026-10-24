## ADDED Requirements

### Requirement: Saves before the statistics have an empty history

A save written before the statistics screen has no history key. Loading it SHALL give the world an empty history, with no finished seasons and a season in progress that has recorded nothing, and SHALL NOT change the save's version.

#### Scenario: A save without a history loads
- **WHEN** a save with no `statistics` key is loaded
- **THEN** the world's history has no finished seasons, and the world otherwise equals the one the save describes

#### Scenario: A history survives save and load
- **WHEN** a world with 5 finished seasons and a season in progress is saved and loaded
- **THEN** the loaded world's history equals the saved one
