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
