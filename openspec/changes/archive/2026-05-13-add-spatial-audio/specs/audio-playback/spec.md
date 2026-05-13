## ADDED Requirements

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
