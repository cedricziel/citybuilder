## ADDED Requirements

### Requirement: Workers walk out from the gather sites

Each operational player lumberjack hut or mine with no building issue SHALL show one worker. The worker SHALL:
- walk from a free tile beside the site, one 4-connected step at a time over free grass and road, to a free tile beside the nearest forest tile (hut) or mountain tile (mine) within `World.lumberjackCatchmentRadius` of the site's footprint;
- work there facing it;
- walk back by the same tiles, drawn with the carrier frames for logs (hut) or a crate (mine);
- rest at the site.

A site with an issue, or with no tree or rock it can reach, SHALL show no worker. A worker's position SHALL be a pure function of the site, the tiles around it and the animals' day clock. Workers SHALL stand still at night, while the game is paused, and with Reduce Motion on. They SHALL sort by the depth of their feet. At most 16 workers SHALL be drawn, none below zoom 0.5, and none outside the visible tiles plus the sprites' screen margin.

#### Scenario: A woodcutter walks out and back
- **WHEN** a working lumberjack hut stands two tiles from a forest at midday
- **THEN** over one round trip its worker stands only on free tiles, reaches a tile beside the forest, and walks back carrying logs

#### Scenario: An idle site stays empty
- **WHEN** a lumberjack hut has no trees in reach, or a mine lacks a road
- **THEN** it shows no worker

#### Scenario: A miner carries a crate
- **WHEN** a working mine is planned on its way back
- **THEN** its worker carries a crate
