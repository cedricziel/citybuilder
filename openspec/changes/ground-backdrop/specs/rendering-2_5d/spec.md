## ADDED Requirements

### Requirement: Plain ground is one backdrop

A tile whose ground is plain grass, beach or water, with no transition, SHALL have no ground sprite of its own. Forest and mountain tiles count as grass. One `SKSpriteNode` under the ground sprites, spanning the screen and clamped to the map, SHALL draw every such tile:
- a shader finds the tile under each pixel;
- it draws that tile's look (its grass variant, beach or water, in the current season) with its animation frames;
- each tile runs on its own phase, from its tile hash;
- every other tile, and the space outside the map, stays transparent.

The backdrop SHALL look the same as a sprite per tile, in every season and at night, under every overlay. Transition sprites, buildings and figures SHALL stay ordinary nodes. A tree or rock object over plain ground SHALL stand alone at the same z and column slot it has over a ground sprite. A terrain change SHALL update which tiles the backdrop draws, and a season change SHALL update its looks.

#### Scenario: Plain ground is one node

- **WHEN** the scene shows grass, beach and sea with no transitions between them
- **THEN** those tiles have no sprite, the backdrop draws them, and the scene holds one backdrop node

#### Scenario: Transition tiles keep their sprites

- **WHEN** a tile has a transition
- **THEN** it keeps its transition sprite and the backdrop leaves it transparent

#### Scenario: Plain ground follows the terrain

- **WHEN** a water tile turns to land
- **THEN** the backdrop draws it as grass, and the water round it, which now has shore transitions, gets sprites

#### Scenario: Trees and rocks keep their place over the backdrop

- **WHEN** a forest tile's ground is plain
- **THEN** its tree clump stands alone at the tile, with the z it has over a ground sprite

#### Scenario: Each tile animates on its own phase

- **WHEN** the backdrop's tiles are laid out
- **THEN** their animation phases come from their tile hashes and spread across the frames

#### Scenario: The ground backdrop follows the season

- **WHEN** the season turns from summer to winter
- **THEN** the backdrop draws the winter looks
