## ADDED Requirements

### Requirement: Seasonal events are drawn on the map

The map SHALL draw:

- flames and a smoke column on each burning building, static under Reduce Motion;
- ruins as their own sprite per footprint size;
- a fire watch's watchman as a walker carrying a bucket while he answers a fire;
- the marked area of a warned or active blight or fever in the area-of-effect overlay's amber "threat" style, at most three shape nodes;
- the reach of a fire watch or physician in the teal "serves" style while placing or selecting one;
- a festival crowd on the plaza during the festival's first season (#127).

Every sprite SHALL come from the approved Claude Design canvas.

#### Scenario: A burning house shows flames

- **WHEN** the snapshot lists a house as burning
- **THEN** the scene draws the flame and smoke effect on it, and removes it on the tick the fire is out

### Requirement: Event status icons

A burning building SHALL show a flame status icon on a red disc. A blighted crop field SHALL show a blight icon with an amber pip. A house that fever holds back SHALL show a fever icon with a red pip. Ruins SHALL show a clear-me icon. A physician short of herbs while a fever is warned or under way SHALL show the existing "short" icon for herbs. These icons SHALL follow the status-icon rules for size, motion and taps.

#### Scenario: Fever icon

- **WHEN** a marked house without a physician in reach is in a fever season
- **THEN** a fever status icon floats over it until the fever ends
