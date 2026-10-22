## ADDED Requirements

### Requirement: Animals graze by the farms

Each operational farm SHALL keep 2–4 sheep and each operational grain farm 1–2 cows. The count SHALL come from a hash of the building. The animals SHALL stand on free grass within 2 tiles of the farm's footprint. A free grass tile has grass terrain, no building and no terrain object (tree or rock). Each animal SHALL graze at its spot and walk to another free spot every 6–10 s. At night an animal SHALL keep its place and not animate. Positions SHALL be a pure function of the farm, slot and tick, and SHALL never change simulation state. At most 30 herd animals SHALL be drawn, none below zoom 0.5, and none outside the visible tile range. With Reduce Motion on, or while the game is paused, animals SHALL stand still.

#### Scenario: Sheep graze beside a farm
- **WHEN** an operational farm stands in open grass at midday
- **THEN** 2 to 4 sheep stand on grass tiles within 2 tiles of it, none on the farm itself

#### Scenario: No animals inside a tree clump
- **WHEN** every grass tile around a farm carries a terrain object
- **THEN** the farm has no animals

#### Scenario: Animals hold still at night
- **WHEN** the same farm is planned at two ticks a minute apart at night
- **THEN** each animal stands in the same place and is not walking

### Requirement: Hens peck by the houses

Each inhabited peasant house SHALL keep 1–2 hens, by a hash of the house, on the front edge of its plot. A hen SHALL hop to a new spot every 3–5 s. By night there SHALL be no hens. At most 24 hens SHALL be drawn, and none below zoom 0.75.

#### Scenario: Hens peck by an inhabited house
- **WHEN** a peasant house with residents is planned at midday at zoom 1
- **THEN** 1 or 2 hens stand on the front edge of its footprint

#### Scenario: Animals stay in budget
- **WHEN** 40 farms in open grass are visible at midday
- **THEN** at most 30 herd animals are planned
