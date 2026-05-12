## ADDED Requirements

### Requirement: Construction-site delivery carrier mission

`Carrier.Mission` SHALL gain a `.deliverToConstructionSite(good:, amount:, fromWarehouse:, toBuilding:)` case (or equivalent producer-source variant; the exact source role is an implementation detail). On arrival, the mission MUST increment the destination building's `materialsDelivered[good]` by `amount`.

#### Scenario: Carrier mission supports deliverToConstructionSite

- **WHEN** a `Carrier` is created with mission `.deliverToConstructionSite(good: .wood, amount: 1, ..., toBuilding: site)`
- **THEN** the carrier walks its path and on arrival increments `site.materialsDelivered[.wood]` by 1

#### Scenario: Construction-site delivery increments materialsDelivered on arrival

- **WHEN** a delivery carrier for 1 plank arrives at a waiting sawmill site with `materialsDelivered[.planks] = 0`
- **THEN** after the arrival tick, the site's `materialsDelivered[.planks]` is 1

#### Scenario: constructionStarted event fires on the flip tick

- **WHEN** the carrier whose delivery causes `materialsDelivered` to satisfy `materialCost` for every good arrives on tick T
- **THEN** tick T's events include `constructionStarted(building: site)` exactly once

### Requirement: Producer prioritizes waiting construction sites

When `spawnCarriersFromProducers` runs, each producer SHALL first check for waiting construction sites on its island that need the good it makes. If such a site exists, the producer's next carrier MUST target the site rather than a warehouse. Only when no waiting site exists for a given good MAY the producer deliver to warehouses.

#### Scenario: Producer prioritizes waiting construction site over warehouse

- **WHEN** a lumberjack hut produces wood, and the island has both a sawmill site waiting for wood and a warehouse with capacity
- **THEN** the producer's next carrier targets the sawmill site, not the warehouse

#### Scenario: Producer falls back to warehouse when no waiting site needs the good

- **WHEN** the lumberjack hut produces wood and no construction site on the island needs wood
- **THEN** the producer's next carrier targets a road-connected warehouse as before
