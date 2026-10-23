## ADDED Requirements

### Requirement: Fish jump near the coast

By day, every 8–15 s of scene time, one fish SHALL jump from a visible open-water tile (water on all eight sides) within 4 tiles of land, picked by a seeded generator. It SHALL make a short arc with a three-frame fish drawn in code, and a splash ring SHALL spread where it dives back in. Only one jump SHALL show at a time, at most 3 nodes. The fish SHALL be nodes of their own above the water and SHALL sort by the depth of the tile they jump from. No new jump SHALL start at night or while the game is paused, and a jump under way SHALL hold still. There SHALL be no fish with Reduce Motion on or below zoom 0.5.

#### Scenario: A fish jumps near the coast
- **WHEN** open water lies within 4 tiles of the land in view, by day
- **THEN** within 15 s a fish jumps from an open-water tile within 4 tiles of land, in at most 3 nodes, and the next jump comes 8–15 s later

#### Scenario: No fish
- **WHEN** it is night, the zoom is below 0.5, or Reduce Motion is on
- **THEN** no fish jumps

### Requirement: Sawdust puffs at the sawmills

Each working player sawmill in view (operational, with no building issue) SHALL show pale sawdust puffs at the middle of its front edge, from one emitter per mill that reuses the smoke puff texture. At most 8 mills SHALL show sawdust, by id. An emitter SHALL go back to a pool when its mill stops working or leaves the view, and come from the pool when one is needed. The puffs SHALL hold still at night and while the game is paused. There SHALL be no sawdust with Reduce Motion on or below zoom 0.5.

#### Scenario: Sawdust puffs at a working sawmill
- **WHEN** a working sawmill is in view by day
- **THEN** sawdust puffs at its front, and stops when the mill has a building issue

#### Scenario: Sawdust rests
- **WHEN** it is night or the game is paused
- **THEN** the puffs hold still, and with Reduce Motion or below zoom 0.5 there is no sawdust
