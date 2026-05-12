## Why

After `enrich-audio-world`, the city is acoustically alive but spatially flat — a sawmill on the far edge of the map sounds exactly the same as one right under the camera. The four-bus mixer was chosen in `add-audio-foundation` (design D4) specifically so that an `AVAudioEnvironmentNode` could later be slipped between the `loop` bus and the main mixer without breaking cue routing. This is that change. Per-building loops gain a 3D position derived from the entity's tile coordinate; the listener moves with the camera. Distance attenuation and stereo panning fall out naturally. Music, UI, and ambient stay 2D — they pass through their existing buses and skip the environment.

The result: zoom in on a sawmill, hear it loud and centered; pan past it, hear it fade to the right and quiet down. Without spatial audio the existing loop bus would have to be a uniform bed; with it, the loops become a navigational cue.

## What Changes

- Insert `AVAudioEnvironmentNode` between the `loop` mixer and the engine's main mixer. Music, SFX, and ambient buses continue to connect directly to the main mixer. (`audio-playback` modified.)
- Add `position: TileCoordinate` to `Bindings.Cue` as a non-Codable companion provided at dispatch time by the coordinator — the coordinator reads the position from the event's primary entity by consulting the `WorldSnapshot` cached from the last `consumeSnapshot` call. (`audio-playback` modified.)
- Expose a `listenerPosition: TileCoordinate?` setter on `AudioStack` that the renderer drives once per second (not per frame — listener jitter is audible). The renderer reads the camera's center tile and pushes it. (`audio-playback` modified, `rendering-2_5d` modified.)
- Distance attenuation uses `AVAudioEnvironmentNode.distanceAttenuationParameters` with sensible defaults: reference distance 4 tiles, max distance 32 tiles, rolloff 1.0 (inverse). Tunable through `AudioSettings.spatialReferenceDistance` and `.spatialMaxDistance` for accessibility and platform tuning.
- Skip spatial routing for non-loop cues by default. A `spatialize: Bool` on `Bindings.Cue` overrides per-cue if a future SFX (e.g. carrier delivery) wants positional treatment, but defaults to true only for cues on the `.loop` bus.
- No new audio content. This is engine-graph work plus a small renderer hook. The `enrich-audio-world` content (saw loop, lumberjack loop) is what becomes spatialized.
- Accessibility: an `AudioSettings.spatialAudioEnabled: Bool` flag (default true) bypasses the environment node entirely when off. Hearing-impaired players or those on mono output can flatten the mix.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `audio-playback`: engine graph gains `AVAudioEnvironmentNode` inserted between the loop mixer and main; per-cue spatial routing; listener position update API.
- `rendering-2_5d`: the renderer's `Camera` exposes `centerTile()` and pushes it to the audio listener at most 1 Hz.

## Impact

- **CityAudio** — `AudioEngine` rebuilds the graph: `loop → environmentNode → mainMixer`. `EngineCuePlayer.playLoop` reads the cue's per-entity position (passed by the coordinator from the cached snapshot) and sets `player.position` on the `AVAudioEnvironmentNode`'s 3D listener space. `AudioStack` gains `setListenerPosition(_ tile: TileCoordinate?)`. Tests cover the bypass case and the conditional routing.
- **CityCore** — no changes. Tile coordinates are already first-class. `WorldSnapshot.buildings` already exposes anchor tiles.
- **CityRender2D** — `IsoWorldScene` already owns the camera. New seam: a `cameraListener: ((TileCoordinate) -> Void)?` callback fires at most once per second from inside the scene's tick. App shells pass `audio.setListenerPosition`.
- **CityUI** — `GameSession.audio` is unchanged; the listener position flows through the renderer, not the session.
- **Resources/Audio/** — unchanged.
- **Performance** — `AVAudioEnvironmentNode` adds a per-source DSP cost. With ~10 operational loops, total CPU stays under 1% on a baseline iPhone. The bypass flag is the escape hatch for low-end targets.
- **Determinism** — the listener position is presentation state derived from `Camera`, which is part of `World` and survives save/load. The 1 Hz throttle is wall-clock-driven (presentation timing); does not affect replay equality.
- **Settings UI** — `AudioSettingsView` gains a "Spatial audio" toggle and (optionally) tuning sliders for reference / max distance. iCloud sync covers the new keys.
- **No save-format change.** Spatial parameters are user settings, not world state.
