## MODIFIED Requirements

### Requirement: Codable snapshot save format
A save SHALL be a single file containing the JSON-encoded `World` value plus a top-level `version` integer. The file MUST be self-describing: loaders MUST refuse to load a save whose version is unknown. The current write format version is `2`; loaders MUST accept version `1` and version `2` saves. Version `1` saves MUST be migrated in memory to the version `2` schema during load.

#### Scenario: Unknown version refused
- **WHEN** a save with a future `version` value (e.g. 99) is opened
- **THEN** the loader reports an error `unknown_save_version` and does not attempt to decode the body

#### Scenario: Version 1 save loads successfully
- **WHEN** a save with `version: 1` (the MVP format) is opened
- **THEN** the loader decodes the file, applies the v1→v2 migration, and returns a valid v2 `World`

#### Scenario: Version 2 save loads without migration
- **WHEN** a save with `version: 2` is opened
- **THEN** the loader decodes the file directly into a v2 `World` without applying migrations

#### Scenario: Save writes use current version
- **WHEN** the persistence layer writes a save
- **THEN** the written file's top-level `version` field equals `2`

## ADDED Requirements

### Requirement: Versioned migration pipeline
The persistence layer SHALL host a versioned migration pipeline that applies an ordered sequence of `Migration` functions, each converting a `version: N` payload into a `version: N+1` payload. New schema versions MUST be added by appending a new `Migration` function; loaders MUST always run the chain from the loaded version up to the current write version.

#### Scenario: v1 to v2 migration chain runs once
- **WHEN** a `version: 1` save is loaded
- **THEN** exactly one migration function (`Migration_v1_to_v2`) is invoked and the resulting in-memory payload is `version: 2`

#### Scenario: v2 save bypasses migration
- **WHEN** a `version: 2` save is loaded
- **THEN** no migration function is invoked

#### Scenario: Migration is pure
- **WHEN** the same `version: 1` save bytes are loaded twice
- **THEN** the two resulting v2 payloads are byte-identical when re-encoded

### Requirement: v1→v2 migration semantics
The `Migration_v1_to_v2` function SHALL produce a v2 `World` from a v1 `World` with the following deterministic transformations: (a) set `layout = "single-island"`; (b) move every `warehouses[i]` into a `goodsBuffers[i]` entry tagged with kind `.warehouse`; (c) initialize `ships = []`; (d) initialize `routes = []`; (e) initialize the `islands` list with a single entry whose tile-count equals the count of non-water buildable tiles and whose `climate = .temperate`; (f) bump `version` from 1 to 2. No other field SHALL be altered.

#### Scenario: Migrated save loads as single-island layout
- **WHEN** `Migration_v1_to_v2` runs on a v1 save
- **THEN** the resulting world's `layout` field equals `"single-island"`

#### Scenario: Warehouses preserved as goods buffers
- **WHEN** `Migration_v1_to_v2` runs on a v1 save with N warehouses
- **THEN** the resulting world's `goodsBuffers` list contains exactly N entries, each with kind `.warehouse` and matching capacity, stored stock, and tile coordinates

#### Scenario: Migrated save has no ships or routes
- **WHEN** `Migration_v1_to_v2` runs on a v1 save
- **THEN** the resulting world's `ships` and `routes` lists are both empty

#### Scenario: Migrated save round-trips against fresh single-island
- **WHEN** a v1 save is migrated, played forward 0 ticks, re-saved as v2, and a fresh v2 single-island game is created with the same seed and same input history
- **THEN** the two v2 worlds are byte-identical when Codable-encoded

#### Scenario: Migration preserves money and population balance
- **WHEN** `Migration_v1_to_v2` runs on a v1 save with money balance `M` and population `P`
- **THEN** the resulting world's money balance is `M` and population is `P`

### Requirement: Migration fixture coverage
The persistence test suite SHALL include at least one binary fixture per supported source version that exercises every migration function. Each fixture MUST be checked into the repository as a `.json` file under `Tests/CityPersistenceTests/Fixtures/saves/`. The test suite MUST fail if a fixture is missing for any source version that has a registered migration.

#### Scenario: v1 fixture exists and migrates cleanly
- **WHEN** the persistence test suite runs
- **THEN** a fixture at `Tests/CityPersistenceTests/Fixtures/saves/v1_single_island.json` is loaded, migrated to v2, and validated against expected post-migration field values
