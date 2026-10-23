## ADDED Requirements

### Requirement: Animals keep their round when the pasture changes

The scene SHALL keep each animal's round (its tiles, in walking order) from tick to tick, and SHALL keep it while every tile on it is still open: free grass for a herd animal, free grass or road for a hen. When a tile on the round closes, the animal SHALL plan a new round through the open tiles, starting at the tile it was heading for, or at the nearest open tile when that one has closed, and SHALL walk there from the spot where it stands. A building or road placed on the pasture or yard SHALL never make an animal jump. A round no longer drawn (its home off screen or over budget) SHALL be forgotten; the next time the animal is drawn, its round starts afresh from the farm, slot and day clock. Each game SHALL get its own map view, so the animals and workers of another game never carry over.

#### Scenario: No jump when the pasture is built on
- **WHEN** a road tile is laid on a farm's pasture every few ticks, with the farm's sheep in view
- **THEN** no sheep moves more than one tile between two ticks, and a sheep that stands still stands on free grass
