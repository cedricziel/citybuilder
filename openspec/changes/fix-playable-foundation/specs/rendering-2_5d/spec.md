## ADDED Requirements

### Requirement: Road-access marker

The world snapshot SHALL list every building, other than roads, that has no road tile orthogonally adjacent to its footprint. The renderer MUST draw a "no road" marker above each listed building, and MUST remove the marker as soon as a road touches the building. The building inspector MUST show a "Road:" line that reads "connected" or "none".

#### Scenario: Snapshot lists a building without an adjacent road

- **WHEN** a house stands with no road tile next to any of its footprint tiles
- **THEN** the snapshot's set of road-disconnected buildings contains the house

#### Scenario: A touching road clears the snapshot entry

- **WHEN** a road is placed on a tile orthogonally adjacent to that house's footprint and one tick runs
- **THEN** the snapshot's set of road-disconnected buildings no longer contains the house

#### Scenario: Disconnected building sprite carries the no-road marker

- **WHEN** the renderer builds the sprite for a building listed as road-disconnected
- **THEN** the building node has a child named `overlay-no-road`

#### Scenario: Inspector reports road access

- **WHEN** the inspector is opened on a building listed as road-disconnected
- **THEN** its lines include "Road: none"
