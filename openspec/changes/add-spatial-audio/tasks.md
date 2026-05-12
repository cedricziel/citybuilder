## 1. M1 — DispatchedCue + coordinator position resolution (CityAudio)

- [ ] 1.1 Tests-first: translate `#### Scenario: Loop cue carries the entity's position`, `#### Scenario: Non-entity events have nil position`, and `#### Scenario: Coordinator falls back to nil before any snapshot has been consumed` into failing tests.
- [ ] 1.2 Implement to green: introduce `DispatchedCue { cue, position }`. Change `AudioCoordinator.CueDispatcher` typealias to `(DispatchedCue) -> Void`. Resolve `position` inside `consume(events:)` by looking up `event.primaryEntityID` in the cached `WorldSnapshot.buildings[id]?.anchor`.
- [ ] 1.3 Update existing test recorders to take `DispatchedCue` (one-line change per call site). Confirm prior tests still pass.

## 2. M2 — AVAudioEnvironmentNode in the loop chain (CityAudio)

- [ ] 2.1 Tests-first: translate `#### Scenario: Loop bus routes through the environment node`, `#### Scenario: Music bus bypasses the environment node`, and `#### Scenario: Bypass toggle removes the environment node` into failing tests in `CityAudioTests`.
- [ ] 2.2 Implement to green: extend `AudioEngine.init` to attach `AVAudioEnvironmentNode`, connect `loop → environment → main`. Music / SFX / ambient connections unchanged.
- [ ] 2.3 Implement to green: `AudioEngine.setSpatialEnabled(_:)` rebuilds the loop chain (detach environment, reconnect loop→main directly, or restore). Idempotent.

## 3. M3 — Spatialized loop playback (CityAudio)

- [ ] 3.1 Tests-first: translate `#### Scenario: Spatialized loop applies the cue position to the player`, `#### Scenario: Unspatialized cue ignores position`, and `#### Scenario: Cue defaults to spatialized on the loop bus` into failing tests.
- [ ] 3.2 Implement to green: `EngineCuePlayer.playLoop` reads `dispatchedCue.position`, converts to `AVAudio3DPoint` (`x = tile.x`, `y = 0`, `z = tile.y`), and applies via the player's `AVAudio3DMixing` properties when connected through the environment node. `Bindings.Cue` gains an optional `spatialize: Bool` with default `nil` (= spatialize iff `bus == .loop`).
- [ ] 3.3 Refactor under a green bar.

## 4. M4 — Listener position update from camera (CityRender2D + CityAudio)

- [ ] 4.1 Tests-first: translate `#### Scenario: Camera-center tile is exposed`, `#### Scenario: Listener push throttled to 1 Hz`, and `#### Scenario: Listener position writes to environment node` into failing tests.
- [ ] 4.2 Implement to green: `Camera.centerTile()` returns the rounded tile-space center. `IsoWorldScene` invokes a `cameraListener: (TileCoordinate) -> Void` callback at most once per second from inside its tick. `AudioStack.setListenerPosition(_:)` writes through to the engine's environment node.
- [ ] 4.3 App-shell wiring: both `CitybuilderiOSApp` and `CitybuilderMacApp` register the listener callback when constructing the SnapshotRendererRegistry factory.

## 5. M5 — Settings + iCloud sync of spatial keys (CityAudio + CityPersistence)

- [ ] 5.1 Tests-first: translate `#### Scenario: Spatial toggle persists`, `#### Scenario: Spatial toggle synced to other device`, and `#### Scenario: Default settings enable spatial audio` into failing tests in `CityAudioTests` and `CityPersistenceTests`.
- [ ] 5.2 Implement to green: `AudioSettings.spatialAudioEnabled: Bool` (default true), `AudioSettings.spatialReferenceDistance: Float` (default 4.0), `AudioSettings.spatialMaxDistance: Float` (default 32.0). Add the three keys to `AudioSettingsSync.Key.all`. `AudioStack` reads them at init and applies to the engine.
- [ ] 5.3 `AudioSettingsView` gains a toggle for spatial; "Advanced" disclosure exposes the two distance sliders.

## 6. M6 — Polish + docs

- [ ] 6.1 README: extend audio docs with the spatial toggle, the listener-throttle, and the default reference / max distances.
- [ ] 6.2 Final `make test`, `make lint`, `make format`.
- [ ] 6.3 Hardware playtest: pan around a city, confirm sawmill panning feels right. — DEFERRED (requires devices and content from `enrich-audio-world`).
- [ ] 6.4 Profile 5-minute play session on baseline iPhone. Capture CPU and audio-render-cycle stats. — DEFERRED (interactive profiling).
- [ ] 6.5 If profile shows >2% CPU on the audio-render thread: add adaptive bypass (auto-disable spatial when CPU budget exceeded). — DEFERRED until profile data.
