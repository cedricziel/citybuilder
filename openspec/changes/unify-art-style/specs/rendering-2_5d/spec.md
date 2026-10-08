## ADDED Requirements

### Requirement: Building sprites anchor at the footprint's bottom vertex

The renderer SHALL place a building sprite (and the placement ghost) so that the sprite's bottom-centre sits on the bottom vertex of the building's footprint diamond. Relative to the anchor tile's centre that vertex is at x = (w − h) × tileWidth / 4 and y = −(w + h − 1) × tileHeight / 2 for a w × h footprint.

#### Scenario: A 2×3 building's sprite sits on its footprint

- **WHEN** the renderer builds the node for a building with a 2×3 footprint
- **THEN** the sprite's position relative to its anchor tile is x = −16 and y = −64

#### Scenario: Square footprints keep their existing anchor

- **WHEN** the renderer builds the node for a building with a 2×2 footprint
- **THEN** the sprite's position relative to its anchor tile is x = 0 and y = −48
