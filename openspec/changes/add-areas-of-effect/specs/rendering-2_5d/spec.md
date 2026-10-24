## ADDED Requirements

### Requirement: Areas of effect while placing and selecting

While a building with a catchment radius is the ghost, or is selected with the inspect tool, the scene SHALL show its area of effect: the outline of every tile within its catchment, drawn in gold over a dark under-stroke with a faint gold tint, on the ground below trees and buildings. The tiles it would work SHALL be highlighted: a tree in reach SHALL brighten on its own node, and open grass a forester would plant SHALL take a stronger gold tint. While a building with a terrain requirement is the ghost, the scene SHALL outline and tint every tile of each valid site within 6 tiles of the cursor and brighten the required terrain's objects there. The overlay SHALL use a fixed number of nodes whatever the area's size, and SHALL vanish, restoring every brightened tree and rock, when the ghost and the selection go.

#### Scenario: Placing a hut outlines its catchment and brightens its trees
- **WHEN** a lumberjack hut ghost stands at an anchor with 18 unoccupied forest tiles within 2 tiles of its plot
- **THEN** the scene outlines the 6 by 6 tiles around the plot and brightens exactly those 18 trees' nodes

#### Scenario: A forester's open grass is tinted
- **WHEN** a forester ghost stands where its catchment holds 12 open grass tiles
- **THEN** the target fill covers exactly those 12 tiles

#### Scenario: Placing a mine shows the valid sites nearby
- **WHEN** the mine is armed and the cursor is within 6 tiles of rock where a mine may stand
- **THEN** the scene outlines every tile of each valid mine plot whose anchor is within 6 tiles of the cursor, and brightens the rock on those tiles

#### Scenario: A selected hut shows its catchment
- **WHEN** the player selects a lumberjack hut with the inspect tool
- **THEN** the scene outlines its catchment and brightens the trees in reach

#### Scenario: The overlay keeps its node count
- **WHEN** the area of effect shows for a hut and then for a mine with dozens of valid sites
- **THEN** the overlay layer holds no more than three nodes both times

#### Scenario: Trees return to normal
- **WHEN** the player disarms the hut tool
- **THEN** the overlay is gone and no tree keeps its brightening
