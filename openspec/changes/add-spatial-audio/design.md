## Context

The audio engine graph today connects each of the four mixer buses (`music`, `sfx`, `loop`, `ambient`) directly to `engine.mainMixerNode`. `EngineCuePlayer` attaches `AVAudioPlayerNode` instances and connects them to the bus mixer. Listener and source position are not modeled — AVAudioEngine treats every player as centered, equal amplitude across the stereo field.

`enrich-audio-world` adds per-building loop cues that all share this 2D placement. The result is an undifferentiated wash of loop sound; players can't use it to navigate. The remedy is `AVAudioEnvironmentNode`, which:

- defines a 3D listener (position, orientation)
- exposes a 3D source position on each player connected via `connect(..., format:)` to its input
- applies distance attenuation and panning

The constraint is that we only want spatial treatment for the `loop` bus. Music is decorative, not navigational; UI sounds are always centered; ambient is by definition non-positional. Inserting the environment node *only* between the loop mixer and the main mixer keeps the other three buses untouched.

## Goals / Non-Goals

**Goals:**

- Per-building loops attenuate and pan based on the entity's tile vs. the camera-center tile.
- Audible side: zoom in on a sawmill → loud, centered; pan two screens away → quiet, side-panned.
- Single user toggle (`AudioSettings.spatialAudioEnabled`) bypasses the entire environment for accessibility / mono output.
- Distance parameters tunable in `AudioSettings` so we can calibrate them for the actual game's tile scale.
- No regressions in the music / SFX / ambient buses.

**Non-Goals:**

- Doppler effects. Tile-grid worlds don't have moving sound sources in a way Doppler conveys usefully; the CPU cost isn't justified.
- HRTF / binaural rendering. AVAudioEnvironmentNode's algorithms are good enough for a 2.5D iso city builder; HRTF is for first-person VR.
- Per-listener orientation. The camera rotates only in the iso-projection sense; ear-orientation doesn't change. Listener is fixed-orientation.
- Spatialized SFX for the placement thunk, coin tick, etc. Those play instantly at the moment-of-action and the player's eye is already on the location — adding pan would feel redundant.
- 3D height. The iso world has no z dimension worth speaking of audibly.

## Decisions

### D1. Insert `AVAudioEnvironmentNode` only between the loop bus and main

The engine graph becomes:

```
music  ─► mainMixer
sfx    ─► mainMixer
ambient─► mainMixer
loop   ─► AVAudioEnvironmentNode ─► mainMixer
```

Implementation lives in `AudioEngine.init` — we detach the existing loop→main connection, attach an environment node, reconnect loop→environment→main. Music / SFX / ambient connection paths are unchanged.

**Alternatives considered:**

- *Insert environment between every bus and main.* Rejected — music + UI + ambient gain nothing, and the environment node applies attenuation curves that would unnecessarily fuss with the music level when the camera moves.
- *Per-cue routing decision (no fixed bus assignment).* Rejected — adds runtime branches in the dispatcher and breaks the "buses are stable graph elements" invariant we relied on in the four-bus design.

### D2. Cue position passed by coordinator from the cached snapshot

The cue dispatch closure (`AudioCoordinator.CueDispatcher`) currently receives `Bindings.Cue`. The position needs to ride along but `Bindings.Cue` is loaded from a JSON file that has no per-event position knowledge. Two paths:

(a) Extend `CueDispatcher` signature to `(Bindings.Cue, TileCoordinate?) -> Void`.
(b) Wrap `Bindings.Cue` in a `DispatchedCue` value that the coordinator emits, carrying both the cue and the position.

(b) is cleaner — it keeps `Bindings.Cue` Codable and stable, and (a) requires every existing dispatcher (including the test recorders) to handle an extra parameter. The wrapper is one tiny struct.

```swift
public struct DispatchedCue: Sendable, Equatable {
    public let cue: Bindings.Cue
    public let position: TileCoordinate?
}
```

Position is resolved inside `consume(events:)` by looking up the event's `primaryEntityID` in the last snapshot the coordinator received via `consumeSnapshot`. Non-entity events (`taxesCollected`, `gameOver`) have `position: nil`.

**Alternatives considered:**

- *Embed `position` directly in `Bindings.Cue`.* Rejected — position is per-instance, not per-binding. The cue file says "loop the sawmill sound"; the entity's position is runtime data.
- *Have the dispatcher closure ask `AudioStack` for an entity's position.* Rejected — couples the closure to global state, harder to unit-test.

### D3. Listener position update at 1 Hz, not per-frame

`AVAudioEnvironmentNode.listenerPosition` is a property the audio engine reads on each render cycle. Pushing a new value 60 times a second (or 120 on ProMotion) is fine performance-wise, but the resulting audio panning has audible micro-jitter as the camera oscillates by sub-tile amounts during smooth panning. Spatial audio plays better with smoothed, low-frequency updates.

We update at most once per second. The renderer's `IsoWorldScene` already has a per-frame hook; we throttle there. The audible payoff: panning slowly across tiles produces a smooth left-to-right slide rather than a jittery wobble.

**Alternatives considered:**

- *Per-frame updates.* Rejected per above.
- *Update only on camera-stop.* Rejected — players pan slowly for long stretches; the listener would lag the camera continuously.

### D4. Single accessibility toggle bypasses the environment entirely

`AudioSettings.spatialAudioEnabled: Bool` defaults to `true`. When false:

- `AudioEngine` rebuilds the loop chain to skip the environment node (`loop → mainMixer` directly).
- The loop bus volume falls back to a non-spatial single level.

This is a destructive rebuild (detach + reconnect) so the toggle is intended as a session-level setting, not a per-tick switch. Changing it requires a small audible glitch as the engine reconnects, which is acceptable for a Settings toggle.

**Alternatives considered:**

- *Set listener to "infinitely far" or some sentinel.* Rejected — fragile, and AVAudioEnvironmentNode still applies its DSP cost.
- *Leave the environment node in but zero out the spatialization.* Tempting, but AVAudioEnvironmentNode doesn't have a clean "bypass" flag; setting source positions to (0,0,0) makes everything mono-centered which is not the user expectation.

### D5. Tile-to-meter mapping

`AVAudioEnvironmentNode` thinks in meters by default. We treat one tile as one meter:

```swift
let position = AVAudio3DPoint(x: Float(tile.x), y: 0, z: Float(tile.y))
```

Reference distance defaults to 4 tiles (full volume zone around the listener). Max distance defaults to 32 tiles. Beyond max, the source is muted. These values match the iso camera's typical viewport — at default zoom you see about 16×16 tiles, so a sawmill at the edge of view is at ~12 tiles distance, near reference-attenuation boundaries. Audible and tunable.

### D6. Settings UI gains a spatial toggle and optional tuning

`AudioSettingsView` gains a "Spatial audio" toggle. Two optional sliders ("Reference distance", "Max distance") sit in an "Advanced" disclosure, hidden by default to keep the main panel clean. Defaults are good for the median player.

iCloud-synced keys: `audio.spatialEnabled`, `audio.spatialReferenceDistance`, `audio.spatialMaxDistance`. Added to `AudioSettingsSync.Key.all`.

### D7. Determinism

The simulation is untouched. Spatial parameters live in `AudioSettings` (presentation) and `Camera` (already in `World` — survives save/load via its existing Codable conformance). The 1 Hz listener push is wall-clock-driven and presentation-only; it does not feed back into `World`. Replay equality holds.

## Risks / Trade-offs

- **[Spatial audio is wrong for accessibility — hearing-impaired or one-ear players.]** → Mitigation: D4 bypass toggle. Default state explained in the Credits & Audio section of Settings.
- **[CPU cost of AVAudioEnvironmentNode at scale.]** → Mitigation: only the loop bus passes through; that bus's player count is bounded by operational producers (small even on a maxed island). Profile a 5-minute play session to confirm; abort to non-spatial loop bus if budget exceeded.
- **[Tile-as-meter mapping is wrong for the player's perception.]** → Mitigation: D5's reference / max distances are tunable. We can calibrate after the first playtest.
- **[Camera updates per-frame would jitter — but throttling adds lag.]** → Mitigation: D3's 1 Hz update is a known trade-off. If the lag feels wrong on fast pans, the throttle can be raised to 4–8 Hz with minimal jitter (which becomes more tolerable when paired with AVAudioEngine's smoothing).
- **[The environment-node bypass requires a graph rebuild.]** → Mitigation: D4 marks the toggle session-level; intermediate audio glitch is acceptable in a settings flow.

## Migration Plan

`CueDispatcher` signature changes (D2 wrapper). Every test recorder and the production `EngineCuePlayer.play` need a small update. Mechanical change: rename `Bindings.Cue` to `DispatchedCue.cue` at access sites.

No save-format change. Saves load and run unchanged. New audio settings keys default-initialize when absent.

Rollback is a clean revert.

## Open Questions

- **Should ambient ever be spatialized?** Some ambient beds (forest birds, water) are intrinsically positional. Phase 3 says no for simplicity; a follow-up could route a separate "spatial ambient" sub-bus through the environment if it feels missing.
- **Stereo panning vs. surround.** AVAudioEnvironmentNode supports surround output when the user has a multi-channel setup. Phase 3 lets that fall out naturally — users with AirPods Spatial Audio enabled get a richer experience without extra work.
- **Should the listener orientation rotate with the iso projection's facing?** No on Phase 3 — the camera doesn't actually rotate. If a future "isometric rotation" feature lands, listener orientation comes with it.
