## ADDED Requirements

### Requirement: Building sprites anchor at the footprint's bottom vertex

The renderer SHALL place a building sprite (and the placement ghost) horizontally centred on the building's footprint diamond, with the sprite's bottom edge on the diamond's bottom vertex. Relative to the anchor tile's centre, the sprite's bottom-centre is at x = (w − h) × tileWidth / 4 (the diamond's centre) and y = −(w + h − 1) × tileHeight / 2 (the bottom vertex) for a w × h footprint.

#### Scenario: A 2×3 building's sprite sits on its footprint

- **WHEN** the renderer builds the node for a building with a 2×3 footprint
- **THEN** the sprite's position relative to its anchor tile is x = −16 and y = −64

#### Scenario: Square footprints keep their existing anchor

- **WHEN** the renderer builds the node for a building with a 2×2 footprint
- **THEN** the sprite's position relative to its anchor tile is x = 0 and y = −48
