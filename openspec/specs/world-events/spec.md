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

The following systems SHALL emit events for the listed state changes:

- **Production system**: `productionCycleCompleted(producer:building:outputs:)` on completion of one cycle; `productionStalled(producer:reason:)` on the tick a stall starts; `productionResumed(producer:)` on the tick a stall ends.
- **Carrier system**: `carrierDeparted(carrier:from:good:)` on spawn; `carrierArrived(carrier:at:good:amount:)` on delivery / retrieval arrival.
- **Building advance**: `constructionCompleted(building:kind:anchor:)` on the tick a constructing building flips to operational.
- **Command application**: `buildingPlaced(building:kind:anchor:)` on a successful place; `buildingDemolished(building:kind:anchor:)` on demolish; `forestHarvested(at:)` on `.harvestForest`; `placementRejected(kind:anchor:reason:)` on a placement command whose `canPlace` is rejecting (commands are pre-validated by UI today, but the core MUST emit the event if the validation is skipped or fails at apply time).
- **Economy system**: `taxesCollected(amount:newBalance:)` on tax-interval ticks; `upkeepPaid(amount:newBalance:)` on upkeep-interval ticks; `bankruptcyWarning(deficitTicks:graceTicks:)` on the first tick of negative balance; `bankruptcyResolved(newBalance:)` when balance returns to non-negative before grace expires; `gameOver` on the tick `economy.gameOver` transitions to `true`.

Each event MUST be emitted at most once per occurrence per tick.

#### Scenario: Construction completion emits exactly one event

- **WHEN** a single building's `ticksSincePlacement` reaches `buildDurationTicks` on tick T
- **THEN** the `TickResult.events` for tick T contains exactly one `constructionCompleted` event for that building, and tick T+1's events do not contain a duplicate

#### Scenario: Production cycle emits once per cycle

- **WHEN** a sawmill completes one full cycle on tick T (ticksThisCycle resets to 0)
- **THEN** the events for tick T contain exactly one `productionCycleCompleted` for that sawmill

#### Scenario: Stall emits an event the tick the stall begins

- **WHEN** a producer becomes stalled (out of inputs, output full, or no adjacent forest) on tick T after running on tick T-1
- **THEN** the events for tick T contain exactly one `productionStalled` for that producer, and subsequent ticks of the same stall emit no further `productionStalled` events

#### Scenario: Stall resolution emits a resumed event once

- **WHEN** a producer that was stalled becomes unstalled on tick T
- **THEN** the events for tick T contain exactly one `productionResumed` for that producer

#### Scenario: Carrier arrival emits once at the destination tick

- **WHEN** a carrier advances to `hasArrived` on tick T
- **THEN** the events for tick T contain exactly one `carrierArrived` for that carrier, with the same good and amount that were deposited

#### Scenario: Tax interval emits a single event

- **WHEN** the tick count reaches a multiple of `Economy.taxIntervalTicks`
- **THEN** the events for that tick contain exactly one `taxesCollected` whose `amount` equals the credited amount

#### Scenario: Bankruptcy warning emits once at deficit start

- **WHEN** the economy balance becomes negative on tick T after being non-negative on tick T-1
- **THEN** the events for tick T contain exactly one `bankruptcyWarning`, and subsequent negative-balance ticks emit no further warnings until the balance recovers and dips again

#### Scenario: Game over emits exactly once

- **WHEN** the bankruptcy grace expires on tick T and `economy.gameOver` flips to true
- **THEN** the events for tick T contain exactly one `gameOver`, and no further `gameOver` events are emitted on subsequent ticks while the world is in the game-over state

#### Scenario: Building placement emits an event

- **WHEN** a `.place(kind, at:)` command is applied successfully on tick T
- **THEN** the events for tick T contain exactly one `buildingPlaced` whose `kind` and `anchor` match the command, and whose `building` is the newly-allocated `EntityID`

#### Scenario: Demolish emits an event

- **WHEN** a `.demolish(at:)` command is applied successfully on tick T
- **THEN** the events for tick T contain exactly one `buildingDemolished` whose `kind` and `anchor` match the building that was removed

#### Scenario: Forest harvest emits an event

- **WHEN** a `.harvestForest(at:)` command is applied on a forest tile on tick T
- **THEN** the events for tick T contain exactly one `forestHarvested(at:)` with the cleared tile

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
