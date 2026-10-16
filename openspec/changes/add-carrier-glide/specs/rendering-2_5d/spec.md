## ADDED Requirements

### Requirement: Carriers glide and show their load

When a carrier's tile changes, its node SHALL move to the new tile's position over the time since its previous step, clamped to 0.03–0.25 s, instead of jumping. A carrier's frames SHALL come from `carrier-<family>-<facing>-<frame>` for its load's family: logs for wood and planks, barrel for beer and wine, sack for food, grain, flour, bread, hops, grapes, tea leaves, coffee cherries, tea and coffee, and crate for ore, charcoal, iron, tools and any good a pack adds later. When those sprites are missing, they SHALL fall back to the walker frames for the same facing. A carrier SHALL draw just above the road it walks on in depth order, so buildings nearer the camera cover it.

#### Scenario: Carrier glides between tiles
- **WHEN** a carrier steps from one tile to the next between two frames
- **THEN** its node runs a move to the new tile's position instead of jumping there

#### Scenario: Load family from the good
- **WHEN** carriers deliver planks, beer, flour and tools
- **THEN** their load families are logs, barrel, sack and crate

#### Scenario: Carrier sprite falls back to the walker
- **WHEN** the atlas has no `carrier-sack-se-0`
- **THEN** a carrier with a sack facing south-east uses the walker's south-east frames
