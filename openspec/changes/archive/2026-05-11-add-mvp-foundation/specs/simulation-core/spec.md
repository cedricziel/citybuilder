## ADDED Requirements

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
