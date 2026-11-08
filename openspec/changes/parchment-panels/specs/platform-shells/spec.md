## ADDED Requirements

### Requirement: Parchment panels

The inspector callout and its pointer, the build drawer, the Statistics sheet and the history and age banners SHALL share one parchment surface: paper #EDDDB3, a 2-point edge #6B4A29 and ink #3D2914, with panel titles in the system serif design. Parchment panels SHALL draw in the light appearance whatever the system appearance, so their text keeps its contrast on the paper. The build rail, the status pill, the HUD buttons and the minimap SHALL stay on glass.

#### Scenario: Shared parchment colours
- **WHEN** the parchment style is read
- **THEN** its paper is #EDDDB3, its edge #6B4A29 and its ink #3D2914

#### Scenario: Parchment in dark mode
- **WHEN** the system appearance is dark and the inspector callout shows
- **THEN** the callout draws on the same paper with dark ink

### Requirement: Callout shows goods as icons

The inspector callout's header SHALL show the building's picture beside its name. A house's needs SHALL show as one chip per need of its tier, in the tier's order, each with the good's icon and name, and a need the house lacks SHALL be marked short; the chips take the place of the "Needs:" key line. A producer SHALL show its recipe as its inputs' icons, an arrow, and its outputs' icons, each with the amount per cycle. A building's problem SHALL show as an alert with a warning symbol. VoiceOver SHALL read each chip as the good's name followed by "met" or "short".

#### Scenario: Need chips for a house
- **WHEN** the player selects a citizens' house in a Northern European town that has food but no planks
- **THEN** the inspector's need chips are food met and planks short, in that order

#### Scenario: Recipe for a bakery
- **WHEN** the player selects a bakery
- **THEN** the inspector's recipe takes flour and makes bread, in the amounts the production catalog gives

#### Scenario: No recipe for a house
- **WHEN** the player selects a house
- **THEN** the inspector has no recipe

### Requirement: Drawer tiles show what they make

A build drawer tile for a building with a production recipe SHALL show the icon of the recipe's first output in its top-trailing corner. A building with no recipe, such as a house, a road or a forester, SHALL show no badge.

#### Scenario: Output badge on drawer tiles
- **WHEN** the Gather drawer shows a lumberjack hut and a forester
- **THEN** the lumberjack hut's tile shows wood and the forester's tile shows no badge
