## ADDED Requirements

### Requirement: Open water is one backdrop

A water tile whose four corners are all water SHALL have no sprite of its own. One map-sized `SKSpriteNode` under the ground tiles SHALL draw every such tile: a shader finds the tile under each pixel, draws the water sprite's pixels there with its animation frames, and leaves every other tile and the space outside the map transparent. The backdrop SHALL look the same as a sprite per tile, in every season and at night. Shore transitions, beach, ships and wakes SHALL stay ordinary nodes, and a terrain change SHALL update which tiles the backdrop draws.

#### Scenario: Open water is one node

- **WHEN** the scene shows a sea round an island
- **THEN** an open-water tile has no sprite, the backdrop draws it, and the scene holds one backdrop node

#### Scenario: Shore water keeps its transition sprite

- **WHEN** a water tile has a shore transition
- **THEN** it keeps its transition sprite and the backdrop leaves it transparent

#### Scenario: Open water follows the terrain

- **WHEN** a water tile turns to land
- **THEN** the backdrop stops drawing it and the water round it, which now has shore transitions, and those tiles get sprites
