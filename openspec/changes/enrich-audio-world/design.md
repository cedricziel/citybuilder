## Context

`add-audio-foundation` shipped the four-bus mixer (music / sfx / loop / ambient), the `AudioCoordinator` with idempotent loop-start and explicit `stopLoop(for:)`, and the `Bindings` schema with an optional `loop: Bool` per cue. Three things prevent the world from sounding alive:

1. **No loop bindings are wired today.** The Phase 1 bindings file binds only one-shots. The `loop` bus runs silent.
2. **Loop lifecycle has no teardown trigger.** `AudioCoordinator.stopLoop(for:)` exists but nobody calls it. Demolishing a sawmill leaves its loop running forever.
3. **The `ambient` bus has no schema entry.** `bindings.json` has a `music` section but no `ambient` section. The bus is wired in the engine graph but unreachable from JSON.

This change fills those gaps without renegotiating any of the foundation's invariants (CityCore stays framework-free, CLI doesn't link audio, manifest-validates-everything).

## Goals / Non-Goals

**Goals:**

- One looped cue per operational building kind that has a recipe (`sawmill`, `lumberjackHut`). Cues start on `productionResumed`, stop on `productionStalled` *and* on the building leaving the snapshot.
- A continuous ambient track on the `ambient` bus while any building is operational (i.e. once the player has placed and built anything).
- A short one-shot on `carrierArrived` so deliveries are audible without spamming.
- Music ducking — every SFX cue ramps the music bus down 6 dB for 300 ms then back up.
- Phase 2 content actually shipped, with at least one CC-BY entry to exercise the attribution UI path.
- No regressions in `add-audio-foundation` scenarios.

**Non-Goals:**

- Spatial / positional audio (deferred to `add-spatial-audio`).
- Adaptive music (combat-state, day-night). Single shuffled playlist of one track stays Phase 2.
- Per-good carrier sounds (carrying wood vs. planks doesn't change the clink).
- Voiceover / narration.
- Off-screen culling of loops. The buildings dictionary is bounded; the cost of 5 ms of inaudible loop CPU is negligible vs. the complexity of tracking the visible region.

## Decisions

### D1. Snapshot diff drives loop teardown

The coordinator's `consume(events:)` already handles loop start (idempotent on `productionResumed`). It also already handles loop stop on `productionStalled`. The third case — building demolished — is not a stall, it's an absence. `buildingDemolished` events do fire (per `world-events` spec) but the coordinator currently has no binding-side reason to react to them differently from a one-shot.

Rather than complicate the bindings file with a "this event also stops the loop for entity X" hint, we add a separate snapshot-driven pass. After each tick the app shell calls `coordinator.consumeSnapshot(snapshot)`. The coordinator iterates its `activeLoops` map and calls `stopLoop(for: id)` for any entity whose `id` no longer appears in `snapshot.buildings`. This is O(loops) per tick, well bounded.

```swift
@MainActor
public func consumeSnapshot(_ snapshot: WorldSnapshot) {
    let presentIDs = Set(snapshot.buildings.keys)
    for id in activeLoops.keys where !presentIDs.contains(id) {
        stopLoop(for: id)
    }
}
```

**Alternatives considered:**

- *Bind `buildingDemolished` to a synthetic "stop loop" cue.* Rejected — couples the bindings schema to lifecycle semantics it shouldn't know about; demolishing a sawmill might fire while no loop is active (player demolishes during stall) and we'd need extra logic to dedupe.
- *Track demolitions inside the coordinator via `buildingDemolished` events.* Workable, but events are a transient stream and any future "loop times out because the building unloaded for reasons other than demolish" case would need yet another event type. Snapshot is the ground truth — diff against it.

### D2. Ambient section as a `MusicSection` sibling

`Bindings` already has a top-level `music: MusicSection?` field. Phase 2 adds a peer `ambient: AmbientSection?`:

```swift
public struct AmbientSection: Codable, Sendable, Equatable {
    public let tracks: [Bindings.MusicTrack]
    public let crossfadeSeconds: Double?
}
```

The ambient track plays as a looped cue on the `ambient` bus, started by `AudioStack` on the first non-empty events array (alongside the existing music auto-start). If multiple tracks are listed, they crossfade over `crossfadeSeconds` (default 4.0) — same shuffle policy as music. Phase 2 ships one track; crossfade machinery exists but is a no-op in the single-track case.

**Alternatives considered:**

- *Treat ambient as a normal binding under `bindings["worldOperational"]`.* Rejected — there is no `worldOperational` `WorldEvent`. Adding one would push a presentation concern into CityCore.
- *Tie ambient start/stop to specific events (e.g. start on first `constructionCompleted`).* Brittle — what about pre-built worlds loaded from save? The audio layer should start ambient when the world *is*, not on a fragile trigger.

### D3. Music ducker observes dispatched cues

Rather than have every cue dispatcher know about ducking, `MusicDucker` sits between `AudioCoordinator` and the production `CueDispatcher` closure. The coordinator's existing dispatcher injection point is the only seam: app shells pass `ducker.intercept(cue)` instead of `player.play(cue)`.

```swift
@MainActor
public final class MusicDucker {
    private let engine: AudioEngine
    private let inner: AudioCoordinator.CueDispatcher
    private let attackSeconds: Double = 0.03
    private let releaseSeconds: Double = 0.30
    private let duckLinear: Float = 0.5  // -6 dB

    public func intercept(_ cue: Bindings.Cue) {
        if cue.bus == .sfx {
            duck()
        }
        inner(cue)
    }
}
```

Ducking is a per-bus volume ramp via a recurring task; not a true sidechain compressor (which would require an `AVAudioUnitDynamicsProcessor` and more knobs than Phase 2 needs).

**Alternatives considered:**

- *AVAudioUnitDynamicsProcessor sidechain.* Rejected — overkill for a 6 dB duck. AVAudioEngine sidechain support is also limited and tedious to configure on iOS.
- *Apply ducking in `AudioCoordinator` directly.* Rejected — coordinator stays decoupled from engine concerns; ducker is an audio-pipeline concern.

### D4. Stall stops, resume starts — the loop binding shape

For `sawmill.caf`:

```json
"productionResumed": [
  { "file": "loop/sawmill.caf", "bus": "loop", "loop": true, "kindFilter": "sawmill" }
],
"productionStalled": [
  { "file": "loop/sawmill.caf", "bus": "loop", "loop": true, "kindFilter": "sawmill" }
]
```

Wait — `productionStalled` shouldn't *start* a loop, it should *stop* one. We need a per-cue "this is a stop-marker" flag, or a separate top-level section.

Cleanest: add `action: "start" | "stop"` to `Cue` with `start` as the default. A stop cue has no associated file (or the file is ignored); the coordinator looks up the entity's active loop and calls `stopLoop` on it.

```json
"productionStalled": [
  { "action": "stop", "kindFilter": "sawmill" }
]
```

A `kindFilter` field on `Cue` restricts the cue to events whose entity's building kind matches. Today the audio layer doesn't have read access to building kinds from inside the coordinator — events carry `kind` in their associated values for some cases (`productionStalled` does NOT, only `producer: EntityID`). We'd need to either:

(a) Add `kind` to `productionStalled` / `productionResumed` in `WorldEvent` (CityCore change), or
(b) Pass building-kind lookups through the snapshot consumer.

Option (a) is a CityCore edit but a small one — both events already carry the producer; adding `kind` is symmetric with `productionCycleCompleted` which already does. Per `world-events` spec the requirement is "emit events for the listed state changes" — adding a payload field to existing cases is additive and doesn't break replay determinism. **This change adopts (a).**

**Alternatives considered:**

- *(b) snapshot-keyed kind lookup.* Rejected — couples audio to snapshot timing in a way that's hard to test and brittle if the snapshot lags the events.
- *Drop `kindFilter` and have one shared loop per producer.* Rejected — a sawmill and a lumberjack hut sound different; one cue per kind is the natural unit.

### D5. CC-BY entry exercises the credits UI

We deliberately pick at least one Phase 2 asset whose license requires attribution (the Robinhood76 saw loop on Freesound, CC-BY 3.0). This isn't necessary for the audio to work — but the attribution-text rendering path in `CreditsView` has not been visually verified against a real entry. Phase 2 is the first time it matters.

The manifest validator and CI check already enforce the attribution-text-required-for-CC-BY rule. Phase 2 only adds the data.

### D6. Determinism unaffected

None of the Phase 2 work touches CityCore beyond adding `kind` to two existing `WorldEvent` cases (D4). The kind value is read from `World.buildings` at emit time, which is fully deterministic. Replay equality holds.

## Risks / Trade-offs

- **[Sawmill saw loop has a perceptible seam at the loop boundary]** → Mitigation: audition the CC0/CC-BY pool for loops with clean seams; if none work, use a longer source (5–8 s) with a 50 ms crossfade in the `scheduleLooped` path. Crossfade implementation is a 10-line `AVAudioMixer` ramp; feasible if needed.
- **[Ambient bird track gets old in long sessions]** → Mitigation: ship two ambient tracks if the audition surfaces a second good candidate; the shuffle code from `MusicPlaylist` generalizes trivially via reuse.
- **[Music ducking feels too aggressive on rapid SFX]** → Mitigation: the duck depth and release time are constants in `MusicDucker`; tunable via Settings if needed. Default 6 dB / 300 ms is the standard "subtle but audible" combo.
- **[CC-BY attribution drift]** → Mitigation: pinned downloads + attribution string in `manifest.json`. CI rejects missing attribution.
- **[Per-building loops cost CPU on a maxed-out island]** → Mitigation: AVAudioPlayerNode is cheap when idle. Each loop player consumes negligible CPU. If we hit hundreds of operational producers, the natural next step is loop pooling — out of scope for Phase 2.

## Migration Plan

Adding `kind` to `productionStalled` / `productionResumed` in `WorldEvent` is a source-level break for any pattern-match that destructures those cases. Today, only the audio bindings code consumes events; the test suite uses `case let .productionStalled(producer)` in a few places. Migration is a one-line rename per call site.

No save-format change. No persistence migration. New audio files are additive; manifest + bindings JSON additions are forwards-compatible.

Rollback is a clean revert of the branch.

## Open Questions

- **Loop crossfade on stop.** Cutting a saw loop hard might pop. Worth a short (50 ms) volume ramp to zero before calling `player.stop()`? Decide during M4 implementation; trivial if the ear says yes.
- **Demolition cue.** Should `buildingDemolished` fire a one-shot crumble/sigh? Phase 2 leaves it silent for taste reasons (a constant demolish-rumble would compete with the construction chime), but the binding is one line away if you want it.
- **Music ducks under loop bus too?** No — Phase 2 keeps ducking SFX-only. Loops are continuous; ducking on every loop start would mean the music is permanently down.
