## ADDED Requirements

### Requirement: Ambient bed section

`Bindings` SHALL accept an optional `ambient` section listing one or more tracks. When present and non-empty, `AudioStack` MUST start the first track as a looped cue on the `ambient` bus on the first non-empty `[WorldEvent]` it consumes. Multi-track ambient sections SHALL use the same no-repeat-within-last-two shuffle policy as the `music` section.

#### Scenario: Ambient track starts on first non-empty events

- **WHEN** `AudioStack` is constructed with a bindings document containing `ambient.tracks` and `consume(events:)` is called with a non-empty array
- **THEN** the ambient track is dispatched as a loop cue on the `ambient` bus exactly once

#### Scenario: Ambient track loops indefinitely

- **WHEN** the ambient cue's file reaches its end inside the engine
- **THEN** the cue is re-scheduled so playback continues without a perceptible gap

#### Scenario: Empty ambient section is a no-op

- **WHEN** the bindings document has no `ambient` section, or its `tracks` array is empty
- **THEN** no ambient cue is dispatched and the `ambient` bus stays silent

### Requirement: Stop-action cues

`Bindings.Cue` SHALL accept an optional `action` field whose values are `start` (default) and `stop`. A `stop` cue MUST NOT initiate playback; it MUST instead invoke `AudioCoordinator.stopLoop(for:)` for the event's primary entity ID. A `stop` cue without an associated `EntityID` (e.g. on a non-entity event) MUST be a no-op.

#### Scenario: Stop cue halts the active loop

- **WHEN** a `productionStalled` event for entity E is dispatched and the bindings file has a `stop`-action cue for that event
- **THEN** the active loop player for entity E is stopped and removed from `activeLoops`

#### Scenario: Stop cue is a no-op without an active loop

- **WHEN** a `stop`-action cue fires for an entity that has no active loop
- **THEN** no error is raised and no playback is initiated

### Requirement: Kind-filtered cues

`Bindings.Cue` SHALL accept an optional `kindFilter` of `BuildingKind`. When set, the coordinator MUST skip the cue unless the event's `kind` payload (where present) equals the filter. Events whose case does not carry a `kind` (e.g. `taxesCollected`) MUST treat a `kindFilter` as a non-match.

#### Scenario: Kind filter restricts a cue to matching events

- **WHEN** a cue bound to `productionResumed` has `kindFilter: sawmill` and the event payload's `kind` is `lumberjackHut`
- **THEN** the cue is not dispatched

#### Scenario: Kind filter matches when payload matches

- **WHEN** the same cue receives a `productionResumed` event with `kind: sawmill`
- **THEN** the cue is dispatched normally

### Requirement: Snapshot-driven loop teardown

`AudioCoordinator` SHALL expose a `consumeSnapshot(_ snapshot: WorldSnapshot)` method intended to be called by the app shell once per tick after `consume(events:)`. The method MUST iterate `activeLoops` and call `stopLoop(for:)` for every entity ID not present in `snapshot.buildings`. The method MUST be idempotent and safe to call from `@MainActor` contexts.

#### Scenario: Snapshot diff stops loops for missing entities

- **WHEN** a sawmill with an active loop is demolished and the next post-tick snapshot no longer contains its entity ID
- **THEN** `consumeSnapshot(_:)` halts the loop player and removes the entry from `activeLoops`

#### Scenario: Snapshot consume is a no-op for unchanged worlds

- **WHEN** `consumeSnapshot(_:)` is called with a snapshot whose `buildings` map contains every currently-looping entity
- **THEN** no `stopLoop` calls fire and no audio state changes

### Requirement: Music ducking

When `AudioSettings.musicDucksUnderSFX` is true, every cue dispatched on the `sfx` bus SHALL cause the `music` mixer's `outputVolume` to ramp down to half its current value over ~30 ms and recover to the configured level over ~300 ms. Loop and ambient cues MUST NOT trigger ducking. Overlapping SFX cues MUST extend the release window rather than stack reductions.

#### Scenario: SFX cue ducks the music bus

- **WHEN** an SFX cue is dispatched and the music bus's `outputVolume` is V
- **THEN** within one audio render cycle the music bus reads `V * 0.5`

#### Scenario: Music recovers after release window

- **WHEN** ~330 ms have elapsed since the most recent SFX cue
- **THEN** the music bus's `outputVolume` reads V again

#### Scenario: Loop and ambient cues do not duck music

- **WHEN** a loop-start or ambient cue is dispatched
- **THEN** the music bus's `outputVolume` is unchanged

#### Scenario: Ducking respects the user toggle

- **WHEN** `AudioSettings.musicDucksUnderSFX` is false and an SFX cue is dispatched
- **THEN** the music bus volume is unchanged

### Requirement: Carrier arrival cue

The shipped Phase 2 bindings SHALL bind `carrierArrived` to a one-shot cue on the `sfx` bus. The audio engine does not need to know the carrier's good or amount — a single cue is dispatched per arrival event regardless of payload.

#### Scenario: Carrier arrival plays a one-shot

- **WHEN** a `carrierArrived` event is dispatched and the Phase 2 bindings are loaded
- **THEN** exactly one cue is dispatched on the `sfx` bus per arrival event
