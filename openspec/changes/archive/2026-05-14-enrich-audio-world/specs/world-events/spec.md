## MODIFIED Requirements

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

## ADDED Requirements

None — this change extends existing requirements rather than introducing new ones.
