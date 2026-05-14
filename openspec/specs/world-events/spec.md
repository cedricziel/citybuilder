# world-events Specification

## Purpose
TBD - created by archiving change add-audio-foundation. Update Purpose after archive.
## Requirements
### Requirement: WorldEvent enum surface

CityCore SHALL define a public `WorldEvent` enum with one case per simulation-meaningful occurrence the audio layer (and any future observer) needs to react to. The enum MUST cover, at minimum: `buildingPlaced`, `buildingDemolished`, `constructionCompleted`, `forestHarvested`, `carrierDeparted`, `carrierArrived`, `productionCycleCompleted`, `productionStalled`, `productionResumed`, `taxesCollected`, `upkeepPaid`, `placementRejected`, `bankruptcyWarning`, `bankruptcyResolved`, `gameOver`. Each case MUST carry the entity ID(s) and any payload needed to identify what happened (e.g. building kind, tile coordinate, good, amount).

The enum MUST be `Equatable` and `Sendable`. It MUST NOT be `Codable`.

#### Scenario: Event enum is exhaustive over MVP capabilities

- **WHEN** the public `WorldEvent` enum is inspected at compile time
- **THEN** each of the cases listed above is present, and adding a new case does not require changing any persisted save format

#### Scenario: Event is not Codable

- **WHEN** code attempts to encode a `WorldEvent` via `JSONEncoder`
- **THEN** compilation fails because `WorldEvent` does not conform to `Encodable`

### Requirement: Tick result aggregates metrics and events

`World.tick()` SHALL return a `TickResult` value type that exposes both the existing `TickMetrics` (wall-clock duration) and an immutable `[WorldEvent]` produced during the tick. `TickMetrics` MUST remain accessible via `TickResult.metrics` so existing profiling callers can migrate by adding a single property access.

#### Scenario: TickResult exposes metrics

- **WHEN** the renderer or CLI calls `world.tick()`
- **THEN** the returned value exposes `.metrics.wallClockNanoseconds` with the same semantics as the prior `TickMetrics` return value

#### Scenario: TickResult exposes events

- **WHEN** a tick completes
- **THEN** the returned value exposes `.events` as an ordered, immutable `[WorldEvent]`

#### Scenario: Empty tick yields empty event list

- **WHEN** a tick advances with no pending commands and no system produces any state change worth signalling
- **THEN** `TickResult.events` is the empty array, not nil

### Requirement: Events are transient

`WorldEvent` instances SHALL exist only inside the `TickResult` of the tick that produced them. The simulation MUST NOT retain events between ticks, MUST NOT include them in `World` state, and MUST NOT include them in any save artifact.

#### Scenario: Events not in World

- **WHEN** `World` is inspected via reflection or its stored properties are enumerated
- **THEN** no property of type `[WorldEvent]` or `WorldEvent` is present

#### Scenario: Save round-trip preserves nothing about events

- **WHEN** a `World` is encoded, decoded, and a tick is run that produces no new events
- **THEN** `TickResult.events` on the decoded world's first tick is the empty array regardless of which events were emitted before the save

### Requirement: Deterministic event order under replay

For any two simulations starting from the same `World` and applying the same input command sequence over the same number of ticks, the concatenation of `TickResult.events` across all ticks MUST be element-wise identical. The system MUST emit events in a stable, deterministic order — sorting by primary `EntityID` ascending, then by a per-case secondary key when an entity is not involved (e.g. economy events sort after entity events within a tick).

#### Scenario: Replay produces identical event sequences

- **WHEN** two simulations start from the same state, advance N ticks with the same input sequence, and concatenate every `TickResult.events`
- **THEN** the resulting two event sequences are equal element-by-element

#### Scenario: Stable ordering inside a single tick

- **WHEN** a single tick emits multiple events involving different entities
- **THEN** those events appear in ascending order of primary `EntityID`, with non-entity events (`taxesCollected`, `bankruptcyWarning`, `gameOver`) following entity events in a fixed declared order

### Requirement: Events emitted by each existing system

The production system's `productionStalled` and `productionResumed` events SHALL each additionally carry the building's `kind: BuildingKind` payload. Existing producer + ordering semantics are unchanged.

The other emit points are unchanged from the archived `add-audio-foundation` spec.

#### Scenario: Stall event carries building kind

- **WHEN** a producer becomes stalled on tick T and the event is captured
- **THEN** the `productionStalled` event's payload exposes the producer's `BuildingKind` (e.g. `.sawmill`)

#### Scenario: Resume event carries building kind

- **WHEN** a stalled producer becomes unstalled on tick T and the event is captured
- **THEN** the `productionResumed` event's payload exposes the producer's `BuildingKind`

#### Scenario: Replay determinism preserved with kind payload

- **WHEN** two simulations replay the same input sequence
- **THEN** the concatenated event log is still element-wise equal across both runs, including the new `kind` field

### Requirement: Events do not influence simulation state

Event emission SHALL be a side effect of state changes that have already been computed. Emitting an event MUST NOT read or write any other field of `World`. Two simulations whose only difference is that one drains `TickResult.events` and the other does not MUST produce byte-identical `World` values.

#### Scenario: Draining events does not affect determinism

- **WHEN** simulation A drains `TickResult.events` into a log and simulation B discards them, with identical inputs over N ticks
- **THEN** the `World` values of A and B are byte-identical when Codable-encoded

### Requirement: Framework-free invariant preserved

The `WorldEvent` enum, the `TickResult` struct, and the event-emission logic SHALL live entirely within the `CityCore` package and MUST NOT import any Apple UI framework (UIKit, AppKit, SwiftUI, SpriteKit, SceneKit, RealityKit, AVFoundation). `CityCore` MUST continue to compile on the Swift Linux toolchain.

#### Scenario: CityCore still Linux-clean after events land

- **WHEN** `CityCore` is built with the Swift Linux toolchain after this change lands
- **THEN** the build succeeds without modification, and `scripts/check-no-apple-ui-imports.sh` continues to pass

### Requirement: CLI event log dump

The headless CLI runner SHALL accept an `--events-out FILE` flag. When provided, the runner MUST write the concatenated `[WorldEvent]` log across all simulated ticks to `FILE` as JSON. Because `WorldEvent` is not `Codable`, the CLI MUST perform a presentation-only conversion to a JSON shape defined in a CLI-side helper, not in `CityCore`. The flag MUST be optional; omitting it produces no event-log artifact.

#### Scenario: CLI writes event log when requested

- **WHEN** the CLI is invoked with `--save FILE --ticks N --events-out events.json`
- **THEN** after N ticks, `events.json` exists and parses as a JSON array whose length equals the total number of events emitted across those N ticks

#### Scenario: CLI omits event log by default

- **WHEN** the CLI is invoked with `--save FILE --ticks N` and no `--events-out`
- **THEN** no event-log file is produced and `CityCore` does not link any encoder for `WorldEvent`
