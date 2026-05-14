# audio-playback Specification

## Purpose
TBD - created by archiving change add-audio-foundation. Update Purpose after archive.
## Requirements
### Requirement: CityAudio package boundary

The audio layer SHALL live entirely inside a new `CityAudio` Swift package under `Packages/CityAudio`. `CityAudio` MUST import only `Foundation`, `AVFoundation`, and `CityCore`. It MUST NOT be linked by the headless `citybuilder-cli` target. It MUST be linked by `CitybuilderiOS` and `CitybuilderMac`.

#### Scenario: CLI does not link audio

- **WHEN** the `citybuilder-cli` target is built and its load commands are inspected (`otool -L` on macOS)
- **THEN** neither `CityAudio` nor `AVFoundation` appears among its linked dependencies

#### Scenario: App targets link audio

- **WHEN** the `CitybuilderiOS` and `CitybuilderMac` targets are built
- **THEN** both link `CityAudio` and resolve `AVFoundation` symbols

### Requirement: Four-bus mixer engine

`CityAudio` SHALL expose an `AudioEngine` type wrapping `AVAudioEngine` with exactly four named mixer buses connected to the engine main output: `music`, `sfx`, `loop`, and `ambient`. Each bus MUST be an `AVAudioMixerNode` whose `outputVolume` is independently settable. The engine MUST NOT be initialized at app launch; it MUST be lazy-initialized on the first cue request.

#### Scenario: Engine has four buses

- **WHEN** the `AudioEngine` is initialized
- **THEN** `engine.bus(.music)`, `engine.bus(.sfx)`, `engine.bus(.loop)`, and `engine.bus(.ambient)` all return distinct `AVAudioMixerNode` instances, each connected to the engine's main mixer

#### Scenario: Engine lazy-initializes on first cue

- **WHEN** the app launches and no audio event has yet been consumed
- **THEN** the underlying `AVAudioEngine.isRunning` is false, no audio file has been opened, and the audio session category has not yet been set

#### Scenario: Engine starts on first cue

- **WHEN** the first `WorldEvent` is dispatched to the `AudioCoordinator` and the binding exists
- **THEN** the underlying `AVAudioEngine.isRunning` becomes true and the cue plays

### Requirement: Bindings file maps events to cues

`CityAudio` SHALL load a JSON `bindings.json` at startup that maps `WorldEvent` case names to an array of candidate cues. Each cue MUST specify a relative file path under `Resources/Audio/`, the target bus (`music` | `sfx` | `loop` | `ambient`), an optional `volume` (0.0–1.0), and an optional `loop` flag. When more than one cue is bound to the same event, the engine MUST pick one at random per dispatch using a non-deterministic RNG (audio playback is presentation-only and does not need to be deterministic).

The bindings file MUST be valid even when some events have no entry — an event with no binding plays silently and is logged at debug level.

#### Scenario: Bound event plays its cue

- **WHEN** a `WorldEvent.buildingPlaced` is dispatched and `bindings.json` contains one cue file for that event
- **THEN** the engine schedules and plays that file on the configured bus within one audio render cycle

#### Scenario: Unbound event is silent

- **WHEN** a `WorldEvent.bankruptcyWarning` is dispatched and `bindings.json` contains no entry for that event
- **THEN** no audio is played, no error is raised, and the dispatch is recorded as a "missing binding" debug log entry

#### Scenario: Multiple cues pick one at random

- **WHEN** an event has three candidate cues bound to it and is dispatched 100 times
- **THEN** more than one of the three cues is observed to play across the 100 dispatches

#### Scenario: Malformed bindings fail loudly at load

- **WHEN** `bindings.json` references a file that does not exist in `Resources/Audio/`
- **THEN** engine initialization throws a descriptive error naming the offending entry, and the app falls back to silent operation (no crash)

### Requirement: Manifest file declares license metadata

Every audio file shipped in `Resources/Audio/` SHALL have an entry in `Resources/Audio/manifest.json`. Each entry MUST include: `path` (matching the file location), `title`, `author`, `source` (URL string), and `license` (one of `"CC0"`, `"CC-BY-3.0"`, `"CC-BY-4.0"`, `"Pixabay-Content"`, or a freeform string for proprietary sources). For non-CC0 licenses, the entry MUST also include an `attribution` field with the exact text to display in the credits screen.

#### Scenario: Manifest has an entry for every audio file

- **WHEN** the CI check `scripts/check-audio-manifest.sh` walks `Resources/Audio/*.{mp3,m4a,caf,wav,aac}` (excluding `_candidates/`)
- **THEN** every file path is present as a `path` value in `manifest.json`, and the check exits 0

#### Scenario: Manifest catches orphaned files

- **WHEN** an audio file is added to `Resources/Audio/` without a corresponding manifest entry
- **THEN** `scripts/check-audio-manifest.sh` exits non-zero and prints the offending path

#### Scenario: CC-BY entries require attribution text

- **WHEN** a manifest entry has `"license": "CC-BY-3.0"` and no `attribution` field
- **THEN** the manifest validator rejects the file with an error naming the entry

### Requirement: Credits view reads the manifest

CityUI SHALL render a `CreditsView` that loads `manifest.json` and shows one section per audio entry, including title, author, license, and (when present) a tappable source URL. Entries with `license == "CC0"` MUST NOT require attribution display, but MUST still be listed. The view MUST be reachable from the existing Settings surface.

#### Scenario: Every manifest entry appears in credits

- **WHEN** the credits view is presented
- **THEN** every entry in `manifest.json` is rendered as a row with at least its `title` and `license` visible

#### Scenario: CC-BY entries show attribution text

- **WHEN** the credits view renders an entry with `license == "CC-BY-3.0"` and an `attribution` field
- **THEN** the attribution text is visible in that row

### Requirement: Per-bus volume control

`AudioEngine` SHALL expose per-bus volume setters in the 0.0–1.0 range and a master mute toggle. Setting any volume or toggling mute MUST NOT crash the engine, MUST take effect within one audio render cycle, and MUST persist via the settings layer.

#### Scenario: Volume change applies within one render cycle

- **WHEN** the music bus volume is set to 0.5
- **THEN** the next audio render cycle plays the music bus at half amplitude

#### Scenario: Global mute silences all buses

- **WHEN** `engine.isMuted` is set to true
- **THEN** every bus produces no audible output regardless of its individual `outputVolume`, until mute is cleared

#### Scenario: Volume settings persist

- **WHEN** the user sets the SFX volume to 0.3 and relaunches the app
- **THEN** the SFX bus volume is restored to 0.3 on next launch

### Requirement: Loop lifecycle keyed by EntityID

Cues marked `loop = true` SHALL be associated with the `EntityID` carried by the originating event. Starting a loop MUST be idempotent — dispatching the same loop-starting event for the same entity twice MUST NOT spawn a second player. Stopping a loop MUST require an explicit stop signal (a corresponding "stop" event, or a coordinator-side teardown when the entity leaves the snapshot).

#### Scenario: Repeat start does not stack

- **WHEN** an event that starts a loop for entity E is dispatched, then dispatched again before any stop signal
- **THEN** exactly one player plays for entity E

#### Scenario: Stop signal halts the loop

- **WHEN** the coordinator dispatches the loop-stop for entity E
- **THEN** the player for entity E is stopped, detached from its bus, and its resources released within one audio render cycle

#### Scenario: Phase 1 has no loop bindings

- **WHEN** the initial `bindings.json` shipped in this change is loaded
- **THEN** no cue has `loop = true` (loops are introduced in a later change)

### Requirement: Music shuffle policy

When more than one track is bound to the ambient-music slot, the engine SHALL pick the next track using shuffle with the no-repeat-within-last-two rule. With exactly one track bound, the track MUST loop seamlessly with a configurable optional gap (default 30 seconds of silence between repeats).

#### Scenario: Single track loops with default gap

- **WHEN** Phase 1 ships with one music track bound and no gap override
- **THEN** the track plays, then 30 seconds of silence, then plays again, indefinitely

#### Scenario: Three tracks avoid recent repeats

- **WHEN** three tracks are bound and the playlist plays 30 selections
- **THEN** no track is played twice within any window of three consecutive picks

### Requirement: Missing audio file is silent, not fatal

If a cue's file is missing at runtime (deleted, corrupted, or never bundled in this build configuration), the engine MUST log the failure and continue. It MUST NOT throw to the caller, crash the app, or stop the engine.

#### Scenario: Deleted file plays silently

- **WHEN** a cue references `placement-thunk.caf` and that file is not present in the resource bundle
- **THEN** dispatching the event logs an error and produces no audible output, and subsequent events continue to play normally

### Requirement: iCloud-synced audio settings

Three settings keys SHALL be persisted and synced via the CloudKit key-value store: `audio.musicVolume` (Double, 0.0–1.0), `audio.sfxVolume` (Double, 0.0–1.0), `audio.muted` (Bool). Changes on one device SHALL propagate to the user's other devices subject to the same offline behavior as save sync.

#### Scenario: Volume change syncs to another device

- **WHEN** the user lowers the music volume on iPad to 0.2 and brings their Mac online
- **THEN** within one sync cycle, the Mac's music volume reads 0.2

#### Scenario: Offline volume change is queued

- **WHEN** the user changes a volume setting while offline
- **THEN** the change is persisted locally and queued for upload at the next sync opportunity

### Requirement: AudioCoordinator consumes per-tick events

`CityAudio` SHALL expose an `AudioCoordinator` type that accepts a `[WorldEvent]` per tick and routes each event through the bindings table to the engine. The coordinator MUST be the only public entry point the app shells use to dispatch audio. It MUST be safe to call from the main actor.

#### Scenario: Coordinator dispatches every event

- **WHEN** the app shell calls `coordinator.consume(events: result.events)` with three events
- **THEN** the coordinator looks up bindings for each of the three events in declared order

#### Scenario: Coordinator is main-actor safe

- **WHEN** `AudioCoordinator` methods are inspected via the Swift concurrency model
- **THEN** every public method is callable from `@MainActor` contexts without compiler warnings

### Requirement: Manifest and bindings ship from project repository

Both `Resources/Audio/manifest.json` and `Resources/Audio/bindings.json` SHALL be hand-authored, version-controlled files. The audio layer MUST NOT generate either at build time. CI MUST verify both files parse and that bindings reference only files present in the manifest.

#### Scenario: Bindings reference manifest paths

- **WHEN** `scripts/check-audio-manifest.sh` runs
- **THEN** every `file` value in `bindings.json` matches a `path` value in `manifest.json`, and the script exits 0

#### Scenario: Orphan bindings fail CI

- **WHEN** a binding references a file not listed in the manifest
- **THEN** the check exits non-zero and names the offending binding entry

### Requirement: Environment node on the loop bus

The audio engine graph SHALL insert an `AVAudioEnvironmentNode` between the `loop` mixer and the engine's main mixer when `AudioSettings.spatialAudioEnabled` is true. The `music`, `sfx`, and `ambient` buses MUST connect to the main mixer directly without passing through the environment node.

#### Scenario: Loop bus routes through the environment node

- **WHEN** `AudioEngine` is initialized with `spatialAudioEnabled = true`
- **THEN** the loop mixer's output node is the `AVAudioEnvironmentNode` and the environment node connects to the main mixer

#### Scenario: Music bus bypasses the environment node

- **WHEN** the same engine is inspected
- **THEN** the music, sfx, and ambient mixers connect directly to the main mixer without an intermediate environment node

#### Scenario: Bypass toggle removes the environment node

- **WHEN** `AudioEngine.setSpatialEnabled(false)` is called
- **THEN** the loop bus is reconnected directly to the main mixer and no environment node is in the loop chain

### Requirement: Cue dispatched with optional position

The `AudioCoordinator.CueDispatcher` typealias SHALL be `(DispatchedCue) -> Void` where `DispatchedCue` carries both the `Bindings.Cue` and an optional `TileCoordinate` derived from the event's primary entity. Coordinator resolution MUST use the most recent `WorldSnapshot` passed to `consumeSnapshot(_:)`; events fired before any snapshot is consumed receive `position: nil`.

#### Scenario: Loop cue carries the entity's position

- **WHEN** a `productionResumed` event fires for entity E whose `buildings[E].anchor` is `(5, 7)` and the bindings has a loop cue for that event
- **THEN** the dispatched cue's `position` is `TileCoordinate(x: 5, y: 7)`

#### Scenario: Non-entity events have nil position

- **WHEN** a `taxesCollected` event fires
- **THEN** the dispatched cue's `position` is nil

#### Scenario: Coordinator falls back to nil before any snapshot has been consumed

- **WHEN** an event with an `EntityID` is dispatched before `consumeSnapshot(_:)` is ever called
- **THEN** the dispatched cue's `position` is nil

### Requirement: Spatialized loop playback

When the environment node is in the graph and a loop cue has a non-nil position, the `EngineCuePlayer` SHALL set the player node's `position` (an `AVAudio3DPoint` with `x = tile.x`, `y = 0`, `z = tile.y`) so the listener perceives distance and pan. Cues with `spatialize == false`, or with `bus != .loop`, MUST NOT be spatialized.

#### Scenario: Spatialized loop applies the cue position to the player

- **WHEN** a loop cue at position `(8, 3)` is dispatched with spatial audio enabled
- **THEN** the corresponding `AVAudio3DMixing.position` reads `(8, 0, 3)`

#### Scenario: Unspatialized cue ignores position

- **WHEN** a cue with `spatialize: false` is dispatched at position `(8, 3)`
- **THEN** the player is not connected through the environment node and its position is not applied

#### Scenario: Cue defaults to spatialized on the loop bus

- **WHEN** a loop-bus cue has no `spatialize` field in JSON
- **THEN** it is treated as spatialized

### Requirement: Listener position from camera

`AudioStack.setListenerPosition(_:)` SHALL write the supplied tile coordinate to the environment node's listener position. The renderer SHALL push a new listener position at most once per wall-clock second; sub-tile camera oscillations between updates MUST NOT reach the audio engine. When spatial audio is disabled, `setListenerPosition` MUST be a no-op.

#### Scenario: Camera-center tile is exposed

- **WHEN** the camera's `centerTile()` is invoked with a camera at world center `(8.4, 6.2)`
- **THEN** it returns `TileCoordinate(x: 8, y: 6)` (floor semantics, defined in the `rendering-2_5d` spec)

#### Scenario: Listener push throttled to 1 Hz

- **WHEN** the renderer's per-frame tick fires 120 times within one second (ProMotion)
- **THEN** `setListenerPosition` writes to the environment node at most once across that window

#### Scenario: Listener position writes to environment node

- **WHEN** `AudioStack.setListenerPosition(TileCoordinate(x: 4, y: 5))` is called and spatial audio is enabled
- **THEN** the environment node's `listenerPosition` reads `(4, 0, 5)`

### Requirement: Spatial audio settings

`AudioSettings` SHALL persist three new keys:

- `audio.spatialEnabled: Bool` (default true)
- `audio.spatialReferenceDistance: Float` (default 4.0 — tiles within this distance play at full volume)
- `audio.spatialMaxDistance: Float` (default 32.0 — sources beyond this distance are inaudible)

These keys SHALL participate in `AudioSettingsSync` cross-device sync. Changing the toggle MUST rebuild the engine's loop chain accordingly; changing the distance values MUST update the environment node's `distanceAttenuationParameters` in place without rebuilding the graph.

#### Scenario: Spatial toggle persists

- **WHEN** the user disables spatial audio and relaunches the app
- **THEN** the next session starts with `spatialAudioEnabled = false` and the engine graph reflects the bypass

#### Scenario: Spatial toggle synced to other device

- **WHEN** the user disables spatial audio on one device and a second device pulls cloud settings
- **THEN** the second device's `AudioSettings.spatialAudioEnabled` reads false

#### Scenario: Default settings enable spatial audio

- **WHEN** a fresh install reads `AudioSettings` for the first time
- **THEN** `spatialAudioEnabled` is true, `spatialReferenceDistance` is 4.0, and `spatialMaxDistance` is 32.0

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
