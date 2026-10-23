## ADDED Requirements

### Requirement: Workers walk out from the gather sites

Each operational player lumberjack hut or mine with no building issue SHALL show one worker. The worker SHALL:
- walk from a tile beside the site, one 4-connected step at a time over free grass, road and the site's own terrain, to a forest tile (hut) or mountain tile (mine) at the edge of the woods or rock, next to free grass or road, within `World.lumberjackCatchmentRadius` of the site's footprint, picked by a hash of the site among those it can reach;
- work there among the trees or rock;
- walk back by the same tiles, drawn with the carrier frames for logs (hut) or a crate (mine);
- rest at the site.

A site with an issue, or with no tree or rock it can reach, SHALL show no worker. A worker SHALL finish the trip it is on: the scene SHALL keep each site's trip (its tiles and the day-clock tick it began) and plan a new one only when the worker is back at its rest point, leaving from the same tile. If a tile on the trip stops being walkable, the worker SHALL turn for home from where it stands, along the tiles it has walked. A tree felled or planted in the catchment SHALL never make a worker jump. While it glides between tiles, a worker SHALL sort by the further back of its two ends. When a different world is shown (the tick runs backwards, or the map changes shape), all workers SHALL be dropped and planned again. Workers keep working in winter, as the sim does. Workers SHALL stand still at night, while the game is paused, and with Reduce Motion on. They SHALL sort by the depth of their feet. At most 16 workers SHALL be drawn, sites on screen first, then by id; none below zoom 0.5, and none outside the visible tiles plus the sprites' screen margin.

#### Scenario: A woodcutter walks out and back
- **WHEN** a working lumberjack hut stands two tiles from a forest at midday
- **THEN** over one round trip its worker stands only on free grass, road or forest, never in the hut, works in the forest, and walks back carrying logs

#### Scenario: An idle site stays empty
- **WHEN** a lumberjack hut has no trees in reach, or a mine lacks a road
- **THEN** it shows no worker

#### Scenario: A miner carries a crate
- **WHEN** a working mine is planned on its way back
- **THEN** its worker carries a crate

#### Scenario: No jump when the woods change
- **WHEN** trees are felled and planted in a hut's catchment between ticks, by day, at night and with Reduce Motion on
- **THEN** its worker never moves more than one tile from one tick to the next
