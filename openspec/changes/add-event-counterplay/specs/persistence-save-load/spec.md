## ADDED Requirements

### Requirement: Saves before seasonal events have none

A save written before seasonal events SHALL load with events enabled, no event warned or under way, no festival and zero event counters, at the same save version. If its calendar is active, its first seasonal event SHALL be decided at the next year that reaches the difficulty's first event year. A save with seasonal events SHALL load with its warned event, its fires, watchmen, marked areas, festival, counters and ruins as saved.

#### Scenario: An old save loads without events

- **WHEN** a save with no seasonal-events key and no ruins is loaded
- **THEN** the world has no seasonal event warned or under way, and its other state is as saved

#### Scenario: A fire survives a save and load

- **WHEN** a world with a burning house, a watchman on his way and a warned blight is saved and loaded
- **THEN** the loaded world is equal to the saved one, and the fire is put out on the same tick as it would have been
