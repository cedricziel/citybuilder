# simulation-core Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.
## Requirements
### Requirement: Framework-free core
The `CityCore` package SHALL NOT import any Apple UI framework (UIKit, AppKit, SwiftUI, SpriteKit, SceneKit, RealityKit). Only `Foundation` and `Swift` are permitted imports.

#### Scenario: Core compiles on Linux toolchain
- **WHEN** `CityCore` is built with the Swift Linux toolchain
- **THEN** the build succeeds without modification

### Requirement: Deterministic fixed-tick simulation
The simulation SHALL advance in discrete fixed-duration ticks of 100 ms simulated time (10 Hz). Given identical initial state, identical input sequence, and identical RNG seed, two simulations MUST produce byte-identical state after the same number of ticks.

#### Scenario: Tick is fixed duration
- **WHEN** the simulation advances one tick
- **THEN** exactly 100 ms of simulated time elapses regardless of wall-clock elapsed time

#### Scenario: Determinism under replay
- **WHEN** two simulations start from the same state and apply the same input sequence over N ticks
- **THEN** their resulting states are byte-identical when Codable-encoded

### Requirement: Seeded RNG
All randomness inside the simulation SHALL come from a seeded RNG persisted in the world state. No subsystem MAY use a global RNG or system-clock-seeded RNG.

#### Scenario: RNG seed persists across save/load
- **WHEN** a save is written with RNG state R and loaded
- **THEN** the next RNG draw produces the same value as the next draw before saving

### Requirement: Input command queue
Player inputs (place building, demolish, etc.) SHALL be expressed as `Command` values queued for the next tick boundary. Commands MUST NOT be applied mid-tick.

#### Scenario: Command applied at next tick
- **WHEN** a command is enqueued during tick T
- **THEN** the command's effects are observable starting at tick T+1

### Requirement: ECS-light component storage
Entities SHALL be opaque integer IDs. Components MUST be stored in dense arrays keyed by entity, not as fields on reference types. Systems MUST be pure functions of `(World, inout WorldDelta)`.

#### Scenario: Entity is opaque ID
- **WHEN** any subsystem references an entity
- **THEN** the reference is an integer ID, not a class instance

### Requirement: Snapshot capability
The entire `World` value SHALL be `Codable`. Encoding and decoding MUST round-trip without information loss for any valid simulation state.

#### Scenario: Save/load round-trip
- **WHEN** a world W is encoded and then decoded
- **THEN** the decoded world equals W under structural equality

### Requirement: Performance budget
A single tick SHALL complete in under 5 ms on a baseline iPhone target for an MVP-sized maxed-out island. Tick time MUST be observable for profiling.

#### Scenario: Tick time instrumented
- **WHEN** the simulation runs in debug or profiling mode
- **THEN** each tick exposes its wall-clock duration via a metrics interface

### Requirement: Headless runnability
The simulation SHALL be runnable from a command-line tool that loads a save, applies N ticks, and writes the result, with no Apple UI framework loaded.

#### Scenario: CLI runner steps simulation
- **WHEN** the CLI tool is invoked with `--save FILE --ticks N`
- **THEN** it loads the save, advances N ticks, and prints summary state without launching any UI

### Requirement: Tick returns aggregate result

`World.tick()` SHALL return a `TickResult` value type aggregating the existing `TickMetrics` and the new transient `[WorldEvent]`. The wall-clock duration MUST remain accessible (via `TickResult.metrics.wallClockNanoseconds`) so existing profiling and CI perf gates need only a one-line update at each call site.

#### Scenario: Tick returns TickResult

- **WHEN** `world.tick()` is called
- **THEN** the returned value's type is `TickResult` and exposes both `.metrics` (a `TickMetrics`) and `.events` (a `[WorldEvent]`)

#### Scenario: TickMetrics still observable

- **WHEN** any profiling caller (renderer, CI perf gate, CLI) reads tick duration
- **THEN** `result.metrics.wallClockNanoseconds` returns the same nanosecond value that the prior `tick()` return type returned, with identical semantics

### Requirement: Determinism extends to events

The byte-identical-under-replay invariant SHALL apply to the full `TickResult`. Given identical initial state, identical input sequence, and identical RNG seed, two simulations MUST produce element-wise-equal `[WorldEvent]` sequences across all ticks, in addition to the existing byte-identical `World` requirement.

#### Scenario: Replay event sequences match

- **WHEN** two simulations start from the same state, apply the same input sequence over N ticks, and the concatenation of `TickResult.events` is captured from each
- **THEN** the two event sequences are element-wise equal

#### Scenario: Replay world state remains byte-identical

- **WHEN** the same two-simulation replay scenario runs
- **THEN** the final `World` values are still byte-identical when Codable-encoded, regardless of whether either run drained its event stream

### Requirement: Event emission preserves framework-free invariant

The event emission machinery SHALL live entirely in `CityCore` and MUST NOT introduce any Apple UI framework or AVFoundation import to the package. The existing `scripts/check-no-apple-ui-imports.sh` gate MUST continue to pass.

#### Scenario: CityCore still Linux-clean

- **WHEN** `CityCore` is built with the Swift Linux toolchain after this change lands
- **THEN** the build succeeds without modification

#### Scenario: No new framework imports in CityCore

- **WHEN** `scripts/check-no-apple-ui-imports.sh` runs against the post-change `Packages/CityCore` source tree
- **THEN** the script exits 0

### Requirement: Rival towns stay deterministic

Two worlds created with the same layout, seed, culture, age, difficulty and rival setting, given the same player commands at the same ticks, SHALL be equal after any number of ticks, rivals included. A world saved and reloaded between a rival's decision and its application SHALL continue identically.

#### Scenario: Replayed rival game

- **WHEN** two Hard archipelago worlds with seed 42 each run 3,000 ticks with no player commands
- **THEN** the worlds are equal and each rival owns more buildings than its town center

#### Scenario: Save between decision and application

- **WHEN** a world is encoded and decoded right after a tick in which a rival enqueued commands, and both copies run 100 more ticks
- **THEN** the copies are equal
