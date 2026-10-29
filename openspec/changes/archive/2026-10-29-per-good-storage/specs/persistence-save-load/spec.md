## ADDED Requirements

### Requirement: Saves before per-good storage keep their stock

A save written before goods buffers held each good separately (version 9 and older) SHALL load with every town center, warehouse and port taking its kind's per-good limit. Each SHALL keep every unit it holds. A good held above the limit SHALL stay as it is until it is used, and that store SHALL take no more of that good until its stock drops below the limit.

#### Scenario: Saves before per-good storage keep their stock
- **WHEN** a version 9 save whose town center holds 55 planks and 6 wood in its shared 40-unit store loads
- **THEN** the town center holds 55 planks and 6 wood, has no room for planks and has room for 34 wood

#### Scenario: Overflow drains before the store takes more
- **WHEN** that town center gives up 16 planks and a carrier then brings 5 planks
- **THEN** it takes 1 plank and holds 40
