## ADDED Requirements

### Requirement: Animals graze by the farms

Each operational farm SHALL keep 2–4 sheep and each operational grain farm 1–2 cows. The count SHALL come from a hash of the building. The animals SHALL stand on free grass within 2 tiles of the farm's footprint. A free grass tile has grass terrain, no building and no terrain object (tree or rock). Each animal SHALL graze at its spot and, every 6–10 s, walk to a 4-connected neighbouring free tile, so every tile a walk passes over is free grass. Animals SHALL move by a day clock that stops at night: at dusk each animal SHALL keep the place it reached and stop animating, and at dawn it SHALL carry on from there. In winter there SHALL be no animals, because the herds and hens are kept inside. Positions SHALL come from the farm, slot and day clock, and from the round the scene keeps (see "Animals keep their round when the pasture changes"), and SHALL never change simulation state. At most 30 herd animals SHALL be drawn, the budget going to the farms nearest the camera centre first, none below zoom 0.5, and none outside the visible tile range. With Reduce Motion on, animals SHALL stand still where they were when it came on. While the game is paused they SHALL stop animating. The visible range SHALL use the same screen margin as the scene's sprites. Animals SHALL sort by the depth of their feet (`figureZ(at:)`), like the other figures, so a building nearer the camera covers them.

#### Scenario: Sheep graze beside a farm
- **WHEN** an operational farm stands in open grass at midday
- **THEN** 2 to 4 sheep stand on grass tiles within 2 tiles of it, none on the farm itself

#### Scenario: No animals inside a tree clump
- **WHEN** every grass tile around a farm carries a terrain object
- **THEN** the farm has no animals

#### Scenario: Animals hold still at night
- **WHEN** the same farm is planned at two ticks a minute apart at night
- **THEN** each animal stands in the same place and is not walking

#### Scenario: Panning to a farm gives it animals
- **WHEN** more farms are in view than the herd budget covers, and the camera centres on one of them
- **THEN** that farm and every farm within 8 tiles of the camera centre show their animals

### Requirement: Hens peck by the houses

Each inhabited peasant house SHALL keep 1–2 hens, by a hash of the house, in its yard: the half of an open tile (free grass or road) next to its +x or +y edge. Hens SHALL never stand on the house's own plot, whose log piles, barrels and garden beds are part of the house sprite. A house with no open tile in front SHALL keep no hens. A hen SHALL hop to a new spot every 3–5 s. By night there SHALL be no hens. At most 24 hens SHALL be drawn, the houses nearest the camera centre first, and none below zoom 0.75.

#### Scenario: Hens peck by an inhabited house
- **WHEN** a peasant house with residents is planned at midday at zoom 1
- **THEN** 1 or 2 hens stand on the open tiles just in front of it, none on its plot

#### Scenario: Animals stay in budget
- **WHEN** 40 farms in open grass are visible at midday
- **THEN** at most 30 herd animals are planned

#### Scenario: No jump at dusk or dawn
- **WHEN** a farm's animals are planned on the ticks either side of dusk, and again either side of dawn
- **THEN** no animal moves further than one tile between the two ticks

#### Scenario: Walks stay on free grass
- **WHEN** a farm's pasture is broken up by trees and a house
- **THEN** at every tick each animal stands on a free grass tile

#### Scenario: No animals in winter
- **WHEN** a farm and an inhabited house are planned at midday in winter
- **THEN** there are no animals
