## Why

The audio foundation (archived `add-audio-foundation`) shipped with four bound one-shots (placement thunk, construction chime, coin tick, game-over sting) and one music loop. That covers the discrete moments the player triggers, but the world itself is acoustically inert: a fully-running sawmill is silent, a forest tile is silent, a carrier delivering goods makes no sound. The four-bus mixer was sized to fit per-building loops on the dedicated `loop` bus and a continuous bed on the `ambient` bus — neither has any cues today.

This change lights up those two buses with the missing-from-CC0-Phase-1 sounds (per-building production loops, world ambient bed, carrier delivery clinks), wires the snapshot-driven lifecycle that starts and stops loops as buildings appear / disappear, and adds music ducking so SFX cut through cleanly. It is the second of three audio phases (Foundation → Enrichment → Spatial); the spatial change layers `AVAudioEnvironmentNode` on top of these loops without breaking the cue API.

## What Changes

- Extend `bindings.json` schema with a new top-level `ambient` section paralleling `music`: a track that plays on the `ambient` bus continuously while any building is operational. (`audio-playback` modified.)
- Add a `loop: true` cue type for per-building production loops: bind `productionResumed` (start the loop) and `productionStalled` (stop it) per `BuildingKind`. The `AudioCoordinator` already keys active loops by `EntityID`; the missing piece is the snapshot-driven teardown when an entity leaves the world (demolished or buildings dict no longer contains it). (`audio-playback` modified.)
- Add a one-shot binding for `carrierArrived` producing a soft clink on the `sfx` bus.
- Add music ducking: when any SFX cue plays, the `music` bus volume ramps down by 6 dB for 300 ms then back up. Implemented as a small `MusicDucker` type that sits between `AudioCoordinator` and the engine. (`audio-playback` modified.)
- Wire a new `AudioCoordinator.consumeSnapshot(_:)` hook that the app shell calls with the current `WorldSnapshot` after each tick. The coordinator diffs the snapshot's set of building IDs against its `activeLoops` and calls `stopLoop` for entities that have disappeared. (`audio-playback` modified.)
- Ship Phase 2 content (CC0 audio) under `Resources/Audio/`:
  - `loop/sawmill.caf` — saw loop (Robinhood76 Workshop pack on Freesound, CC-BY 3.0 — requires attribution)
  - `loop/lumberjack.caf` — chop loop (OGA wood/metal pack, CC0)
  - `ambient/forest-birds.caf` — birdsong bed (Magnesus, CC0)
  - `sfx/carrier-clink.caf` — coin-drop clink (Kenney Interface, CC0)
- Update `manifest.json` with the four new entries. The first non-CC0 entry exercises the attribution-text path in the credits UI; surface it visibly.
- Bump the `check-added-large-files` cap in `.pre-commit-config.yaml` to 3 MB and document the audio exception. The Phase 2 sawmill loop is expected to be ~1.5 MB to avoid loop-edge artifacts at lower bitrates.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `audio-playback`: ambient-bed section in bindings, loop lifecycle gated on snapshot membership, music ducking, snapshot-consume hook on the coordinator. Existing one-shot, manifest, credits, and shuffle behavior unchanged.

## Impact

- **CityAudio** — new types: `MusicDucker` (lives between coordinator and engine, observes dispatched cue bus and ramps the music mixer's `outputVolume`), `EngineCuePlayer.startAmbient(_:)` / `.stopAmbient()`, `AudioCoordinator.consumeSnapshot(_:)` with a snapshot-diff loop-pruner. `Bindings` gains an optional `ambient: AmbientSection` field paralleling `music`.
- **CityUI** — `GameSession.step()` now also forwards the post-tick `WorldSnapshot` to a `snapshotConsumer` closure (new optional field paralleling `audioEventConsumer`). App shells pass `coordinator.consumeSnapshot`. Tests cover snapshot-diff teardown.
- **Resources/Audio/** — four new audio files (~2 MB total), one of which is CC-BY 3.0 and triggers the credits-screen attribution path that's been waiting for a real consumer.
- **`.pre-commit-config.yaml`** — `check-added-large-files` max raised to 3 MB. Documented in `.pre-commit-config.yaml` and README.
- **No CityCore changes.** Phase 2 is entirely a CityAudio / CityUI / content concern. `WorldEvent` already covers `productionResumed` / `productionStalled` / `carrierArrived`; no new event cases needed.
- **No save-format change.** Snapshots are already what the renderer consumes; audio just gets a copy.
- **Music ducking** is opt-out via a settings flag (default on). The existing `AudioSettings` model gains a `musicDucksUnderSFX: Bool = true` property.
- **Performance** — ambient loops keep a single `AVAudioPlayerNode` running on the ambient bus regardless of building count. Per-building loops scale linearly with operational buildings, capped naturally by the buildings dictionary; no culling or pooling beyond the existing `loopPlayers` map.
