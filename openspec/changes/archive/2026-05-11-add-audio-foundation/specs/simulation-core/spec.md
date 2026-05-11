## ADDED Requirements

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
