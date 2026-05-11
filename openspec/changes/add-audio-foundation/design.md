## Context

CityCore is the framework-free simulation core (Foundation only, Linux-clean, enforced by `scripts/check-no-apple-ui-imports.sh`). Today `World.tick()` runs five systems (`advanceBuildings`, production, carrier, population, economy) and returns a `TickMetrics` struct with the per-tick wall-clock nanoseconds. Nothing else escapes the tick boundary — no notifications, no async streams, no observation surface for downstream layers. The renderer infers everything from snapshot diffs in `SnapshotReconciliation`; the persistence layer reads only the live `World`; the HUD's `GameSession` mirrors the live `World` and re-renders on tick.

The original MVP design called out that an audio layer would need a `WorldEvent` stream and accepted the work as deferred. We are now picking that up, with the constraint that:

- The simulation MUST stay byte-identical under replay. Adding events MUST NOT introduce non-determinism.
- The headless CLI runner MUST NOT link AVFoundation. CityCore stays Linux-clean.
- The audio layer MUST not couple to the renderer (SpriteKit) — a future SceneKit / spatial audio path needs to slot in without rewriting bindings or the engine.
- Asset reality dictates: most events will not have a sound on day one. The system MUST treat "no binding" as a normal state.

There are already two clean architectural seams we exploit: (1) `World.tick()` is the only mutation entry point, so events emitted from inside `tick()` naturally inherit the deterministic ordering of the tick body; (2) `CityUI.GameSession` already owns the tick loop on the app side, so wiring a consumer there is a single edit.

## Goals / Non-Goals

**Goals:**

- A `WorldEvent` enum stable enough to support audio bindings, scenario assertions in tests, and future analytics — without coupling to AVFoundation or SwiftUI.
- A `TickResult` aggregate that lets every existing `world.tick()` caller migrate by appending `.metrics` to the access path; the events list is opt-in.
- Deterministic event ordering: same save + same input sequence → byte-identical event log AND byte-identical `World`.
- A `CityAudio` package that owns AVAudioEngine, four mixer buses, JSON bindings, JSON manifest, per-bus volume, music shuffle, lazy startup, and missing-binding silence.
- A credits view fed by the manifest, reachable from Settings on every platform.
- iCloud sync of volume sliders + mute via the existing KV-store machinery.
- Phase 1 ships content for the smallest impactful set: one music track, click, placement thunk, construction-complete chime, coin tick on tax, game-over sting.
- "Eventually rich" is reached in two follow-up changes (`enrich-audio-world` for loops + ambient, `add-spatial-audio` for `AVAudioEnvironmentNode`) without re-architecting.

**Non-Goals:**

- Per-building loops (sawmill saw loop, lumberjack chop) — deferred to follow-up.
- Spatial / positional audio — deferred. The four-bus layout has been chosen to accommodate it cleanly later (insert `AVAudioEnvironmentNode` between the loop bus and main mixer; cue routing stays the same).
- Authoring our own music or SFX. We're consuming CC0 packs only.
- Voice / narration. Not in scope.
- Adaptive music tied to game state (combat layer / day-night). Shuffle of a few tracks is enough for foundation.
- Audio analytics, telemetry, or A/B testing of cues.

## Decisions

### D1. Events live inside `TickResult`, returned from `tick()` synchronously

`World.tick()` returns `TickResult { let metrics: TickMetrics; let events: [WorldEvent] }`. Events are produced inside the tick body, collected into a per-tick scratch buffer on `World`, and moved into the returned `TickResult` at the end of `tick()`. The scratch buffer is reset to empty before each tick; events do not survive into the next tick.

```swift
public struct TickResult: Sendable, Equatable {
    public let metrics: TickMetrics
    public let events: [WorldEvent]
}

public mutating func tick() -> TickResult {
    pendingEvents.removeAll(keepingCapacity: true)   // scratch reset
    // ... existing tick body, systems call self.emit(_:) when they need to ...
    let sorted = stableSort(pendingEvents)
    return TickResult(metrics: TickMetrics(...), events: sorted)
}
```

The scratch buffer is `internal`, not stored in `World`'s Codable surface (an exclusion `enum CodingKeys` makes that explicit, or it is `@_implementationOnly` from the encoder's perspective — TBD during implementation, but the spec requires it stays out of save artifacts).

**Alternatives considered:**

- *AsyncStream of WorldEvent.* Rejected — couples the simulation lifecycle to a Swift concurrency primitive, adds main-actor coordination, and means tests cannot synchronously assert on event sequences without spinning the actor. Synchronous tick boundaries match how the rest of the engine works.
- *Combine publisher.* Rejected — same coupling, plus Combine is platform-only and breaks the Linux-clean invariant.
- *Observer / delegate registered on World.* Rejected — non-deterministic listener ordering, mutation hazard if a listener calls back into `World`.
- *Side-channel notification posting (NotificationCenter).* Rejected — string-typed, untyped payload, non-deterministic delivery order, breaks Linux-clean.
- *Events embedded inside `WorldSnapshot`.* Rejected — snapshot is what the renderer diffs each frame, not a tick log. Putting events there would force the renderer to dedupe across frames.

### D2. Events sorted by primary EntityID, then by case ordinal

To keep the event log replay-identical across platforms, we cannot rely on `Dictionary` iteration order. Inside `tick()`, each system appends to `pendingEvents` in whatever order its `for (id, _) in dict` loop happens to choose. Before `tick()` returns, we apply a stable sort:

1. Primary key: `event.primaryEntityID` (ascending, with `nil` meaning "no entity" sorting after all entity-bearing events).
2. Secondary key: a fixed case ordinal (declared in `WorldEvent.caseOrdinal`, hand-maintained next to the enum) for non-entity events like `taxesCollected`, `bankruptcyWarning`, `gameOver`.

`stableSort` is implemented inline using `Array.sorted` plus an index pair (the standard "decorate-sort-undecorate" pattern) because Swift's `sort` is not guaranteed stable.

**Alternatives considered:**

- *Sort by EntityID only.* Rejected — non-entity events would be order-undefined.
- *Preserve declaration order in code.* Rejected — `Dictionary` iteration isn't deterministic, and refactoring system code would silently change event order.
- *Emit events in a fixed system order (production first, then carriers, then economy, then commands).* Tempting, but interleaves with entity-driven systems in ways that are non-obvious. Decorate-sort-undecorate by `(EntityID, caseOrdinal)` is the simplest invariant to spec and check.

### D3. CityCore stays framework-free; events are not Codable

`WorldEvent` lives in CityCore as a plain Swift enum with associated values. It conforms to `Equatable` and `Sendable`. It deliberately does **not** conform to `Codable` — that would tempt callers to persist events, which violates the transient-only requirement, and would force CityCore to declare a JSON shape that any future caller could depend on.

The CLI runner's `--events-out` flag uses a presentation-side encoder in the CLI target (not in CityCore) that pattern-matches `WorldEvent` and writes a stable JSON shape. The audio layer never serializes events — it consumes them directly via pattern matching against bindings.

**Alternatives considered:**

- *Codable WorldEvent.* Rejected per above.
- *Define a separate `WorldEventDTO` in CityCore for the CLI.* Acceptable fallback if the CLI-side encoder becomes painful, but the simpler form (pattern-match in the CLI) is fine for ~15 cases and we can extract if it grows.

### D4. Four mixer buses chosen to support eventual spatial audio without API breakage

The audio engine graph:

```
[music player ]──► [music   mixer]──┐
[sfx players ]──► [sfx     mixer]──┤
[loop players]──► [loop    mixer]──┼──► [main mixer] ──► [output node]
[ambient pl. ]──► [ambient mixer]──┘
```

When we later add positional audio (Phase 3), an `AVAudioEnvironmentNode` is inserted between the loop bus and the main mixer:

```
[loop players]──► [loop mixer]──► [AVAudioEnvironmentNode]──► [main mixer]
```

This works because each loop player is associated with an `EntityID`, which gives us the source position to set on the environment node. Cue routing logic does not change. The music / sfx / ambient buses skip the environment node and go straight to main.

**Alternatives considered:**

- *Single mixer with per-source attenuation curves.* Rejected — no clean way to apply music-ducking-under-SFX as a per-bus rule, and refactor cost to introduce buses later is higher than the four-bus cost up front.
- *Per-cue node graphs (no buses).* Rejected — explodes graph complexity and removes the single point of attaching the environment node later.
- *Use SpriteKit's `SKAudioNode`.* Rejected — couples audio lifecycle to scene-tree lifecycle. We'd lose audio when nodes get culled off-screen by the existing tile reconciler. AVAudioEngine is independent of the scene tree, which is what we want for music + UI audio. Spatial loops can opt back into positional via the environment node when we get there.

### D5. Bindings are an external JSON file, not Swift constants

`Resources/Audio/bindings.json` is a hand-authored JSON file describing the `WorldEvent` → cue mapping. Format sketch:

```json
{
  "version": 1,
  "bindings": {
    "buildingPlaced": [
      { "file": "ui/place-thunk-01.caf", "bus": "sfx", "volume": 0.8 }
    ],
    "constructionCompleted": [
      { "file": "construction/chime-01.caf", "bus": "sfx", "volume": 1.0 }
    ]
  },
  "music": {
    "tracks": [
      { "file": "music/bards-tale.m4a", "bus": "music" }
    ],
    "shuffle": "no-repeat-within-last-two",
    "gapSecondsBetweenTracks": 30.0
  }
}
```

Designers tune without recompiling. The schema is forward-compatible: future fields (loop, fade-in, source-position-hint) can be added with sensible defaults. Bindings cross-reference manifest paths; CI enforces consistency.

**Alternatives considered:**

- *Swift constant tables (like `SpriteAnimation` catalog).* Rejected — every cue tweak would require an Xcode build. JSON wins for content iteration.
- *Per-event bindings file (`buildingPlaced.json` etc.).* Rejected — operational pain, too many files for a small system.
- *Embed bindings into manifest.* Rejected — bindings change with content design; manifest is metadata. Separation makes audit easier.

### D6. Manifest is the credits source of truth and the CI gate

`Resources/Audio/manifest.json` is the only authoritative record of what audio file came from where under what license:

```json
{
  "version": 1,
  "entries": [
    {
      "path": "music/bards-tale.m4a",
      "title": "Medieval: The Bard's Tale",
      "author": "Brandon75689",
      "source": "https://opengameart.org/content/medieval-the-bards-tale",
      "license": "CC0"
    },
    {
      "path": "construction/saw-loop.wav",
      "title": "Hand Saw Loop",
      "author": "Robinhood76",
      "source": "https://freesound.org/people/Robinhood76/sounds/12345/",
      "license": "CC-BY-3.0",
      "attribution": "Hand Saw Loop by Robinhood76 — CC-BY 3.0"
    }
  ]
}
```

`CreditsView` reads it directly. `scripts/check-audio-manifest.sh` walks `Resources/Audio/*` (excluding `_candidates/`), verifies every file has an entry, every CC-BY entry has attribution text, and every binding's `file` matches a manifest `path`. Pre-commit and CI run the script.

**Alternatives considered:**

- *Compile manifest into Swift.* Rejected — content team should be able to edit it without an engineer.
- *Store license metadata in extended file attributes.* Rejected — fragile across git, opaque to readers, no platform support guarantee.

### D7. Engine is lazy, audio session activation deferred

`AVAudioEngine` startup is ~100 ms (real time, real Phone 14). If we initialize it in `application(_:didFinishLaunchingWithOptions:)`, we pay that cost on every cold launch even for players who never hear a sound (e.g. CI screenshot tests, accessibility-mute users). Instead, the `AudioCoordinator` lazy-initializes the engine on the first cue dispatch.

On iOS, the audio-session category is also set lazily (only when the engine is about to run). This means a launch-and-quit cycle with no audio events leaves the user's Music app untouched. The category is `.ambient` by default, which mixes our music with theirs.

**Alternatives considered:**

- *Eager init in `applicationDidFinishLaunching`.* Rejected — bad citizen on iOS, unnecessary cost for silent sessions.
- *Init on the first tick.* Rejected — tick happens every 100 ms, eager again. First *cue* is the right trigger.

### D8. Missing binding / missing file = silence, never crash

Two failure modes that look similar but happen at different times:

- *Missing binding*: `bindings.json` has no entry for `WorldEvent.bankruptcyWarning`. Coordinator logs at debug, returns. This is the normal state for most events in Phase 1.
- *Missing file*: A binding references `coin-tax.caf` and the file isn't in the bundle. Engine logs at error level, continues. CI catches this earlier via `scripts/check-audio-manifest.sh`, but the runtime path must be safe.

Crashes on missing assets are forbidden. The audio layer fails open and quiet.

**Alternatives considered:**

- *Fatal on missing file at startup.* Rejected — ships fine assets in one configuration, ships broken in another (e.g. iOS build excludes Mac-only files); we don't want a release-build crash.

### D9. Stall and resume events use prior-tick state to avoid duplicate firing

`productionStalled` must fire the tick the stall *begins* — not every tick the producer is in a stalled state. To detect "begins," the production system needs to compare the new stall state with the *previous tick's* stall state. We already store `ProductionProgress.isStalled` on `World`, so this is free: read the old value, set the new value, emit only on transition.

Same for `bankruptcyWarning` (transition from non-negative to negative) and `bankruptcyResolved` (transition from negative to non-negative).

**Alternatives considered:**

- *Emit every tick of stall.* Rejected — produces a torrent of events that the audio layer would have to dedupe.
- *Track in a side channel.* Rejected — duplicates existing state.

### D10. Determinism

The full `TickResult` is byte-identical under replay:

- The simulation logic is unchanged. World mutation order is the same.
- Event emission is a side effect *after* the corresponding state change is computed. Emitting an event reads no other state; it just appends to the scratch buffer.
- The scratch buffer's contents at end-of-tick depend only on which state changes happened, which is deterministic.
- The stable sort by `(EntityID, caseOrdinal)` removes any non-determinism inherited from `Dictionary` iteration order.
- The audio layer's RNG (used for picking among multiple cues) lives in `CityAudio`, not `CityCore`. It is *not* part of replay determinism — audio playback is presentation-only.

The replay test suite gains a second equality check: after running N ticks twice from the same starting state, both `World` values AND both concatenated event logs must be equal.

### D11. CityAudio package boundary

`Packages/CityAudio/`, depending on `Foundation`, `AVFoundation`, and `CityCore`. App targets (`CitybuilderiOS`, `CitybuilderMac`) link it. The CLI target (`citybuilder-cli`) does **not** link it.

This is enforced two ways:

1. `project.yml` does not list `CityAudio` in the CLI target's dependencies.
2. A CI check inspects the built CLI binary with `otool -L` and fails if `CityAudio` or `AVFoundation` appears.

The package exposes only `AudioCoordinator`, `AudioEngine`, `AudioBus` (enum), `AudioSettings` (the volume / mute model), `Manifest` (read-only DTO), and `Bindings` (read-only DTO). Internal types stay internal.

### D12. AudioCoordinator is the single integration point

The app shell wires once:

```swift
@MainActor
final class GameSession {
    let world: World
    let audio: AudioCoordinator   // injected

    func step() {
        let result = world.tick()
        // ... existing snapshot push to renderer ...
        audio.consume(events: result.events)
    }
}
```

`AudioCoordinator.consume(events:)` is the only audio entry point the rest of the codebase ever calls. This keeps audio testable in isolation (mock coordinator), keeps the GameSession aware of one new dependency only, and lets the audio package evolve internally without app-shell churn.

### D13. iCloud sync of audio settings rides on existing infrastructure

`audio.musicVolume`, `audio.sfxVolume`, `audio.muted` go into the same CloudKit KV store the persistence layer already manages. No record-type change, no migration. The existing offline-tolerant queueing applies. The audio layer reads its volumes from a `AudioSettings` observable model that the existing settings UI in CityUI writes to; the persistence layer flushes that model to KV store on settings change.

## Risks / Trade-offs

- **[Tick signature change breaks every call site of `world.tick()` in the codebase]** → Mitigation: a single mechanical rename pass (`result.wallClockNanoseconds` → `result.metrics.wallClockNanoseconds` and `_ = world.tick()` → `_ = world.tick()` with no change). All existing call sites are inside this monorepo. We do this as a dedicated commit in M1.
- **[`Dictionary` iteration non-determinism could leak through if we forget to sort]** → Mitigation: the sort is implemented once in `World.tick()`, after each system returns. A dedicated scenario test asserts replay equality on a multi-entity scenario that would be order-sensitive (e.g. five sawmills all completing cycles on the same tick).
- **[Event spam from per-tick stall checks if we forget the prior-state comparison]** → Mitigation: D9 nails this; the spec scenario "Stall emits an event the tick the stall begins" is the regression guard.
- **[AVAudioEngine startup hitch on first cue]** → Mitigation: lazy init happens off-main if possible (engine creation is fine off main; audio session config must be on main). 100 ms is acceptable for a first cue, especially the launch music track which takes ~1 s of audio file load anyway. Document as a known one-time cost.
- **[CC-BY attribution forgotten in PR]** → Mitigation: `scripts/check-audio-manifest.sh` fails CI if any CC-BY entry lacks attribution text. Pre-commit hook runs it locally too.
- **[Bindings file becomes a giant unmaintainable blob]** → Mitigation: schema versioning (`"version": 1`), and we can split into multiple files later if size demands. Phase 1 ships ~6 bindings; splitting is overkill until we hit dozens.
- **[Free-asset license drift on Freesound / OGA over time]** → Mitigation: every entry has the source URL in the manifest. If a track is relicensed, we can audit. CC0 cannot be revoked, so CC0 assets are safe. CC-BY entries are pinned to a downloaded copy we own; we re-verify on each major release.
- **[Engine running while game paused]** → Trade-off: we let it. Music loops continue even when the simulation is paused (player likely wants ambience as they think). If feedback says otherwise, we add a "pause audio with simulation" setting.
- **[Tests that assert on event sequences become brittle as we add events]** → Mitigation: scenario tests assert "contains expected event(s)" rather than "equals exact event list" where possible, so adding new event cases doesn't break them. Replay-determinism tests check ordering invariance, not specific content.
- **[Loop entity lifecycle (Phase 2) — what stops a loop when the entity is demolished mid-loop?]** → Out of scope for Phase 1 (no loop bindings ship). Phase 2 design will spec the entity-leaves-snapshot stop signal.

## Migration Plan

The tick API changes from `TickMetrics` to `TickResult` — that's a source-level break for every caller. Migration is a one-line edit per site:

- `let metrics = world.tick()` → `let metrics = world.tick().metrics`
- `_ = world.tick()` → `_ = world.tick()` (unchanged)
- Tests that ignore the return value continue to compile unchanged.

We do this migration in a single commit at the start of M1, before any event-emission logic, so the existing test suite stays green through the rename. Once `TickResult` is in place, subsequent commits add the events buffer, the emission calls, and the deterministic sort.

No save-format change. No persistence migration. Saves written before this change load and run unchanged; the first tick after load produces events as expected.

Rollback is a clean revert of all commits on the branch with no data implications.

## Open Questions

- **Phase 1 music track choice.** Three OpenGameArt CC0 medieval tracks have been staged under `Resources/Audio/_candidates/`. We audition and pick one for ship. If none feels right, we either commission or punt music to a later change (the foundation is still useful).
- **Default volumes.** Music 0.6, SFX 0.8 is a reasonable starting point, but should be confirmed on real hardware (medium-loud iPhone speaker vs MacBook speakers behave differently).
- **Should the credits screen also list visual assets (sprites)?** Probably yes for consistency, but that's a CityUI change and out of this change's scope. We add a TODO in `CreditsView` to extend later.
- **CLI event-log shape.** JSON object per event (`{ "case": "buildingPlaced", "entity": 42, "kind": "sawmill", "at": [3, 5] }`)? Or one line per event ndjson? Pick during M1 implementation; not spec-load-bearing.
- **Music ducking under SFX.** Not in Phase 1 specs (the SFX set is too small to justify it). When loops + carrier clinks land in Phase 2, we'll likely want -6dB on the music bus while an SFX is active. Easy to add via the existing four-bus design.
- **Audio session category on Mac apps with multiple windows.** Mac doesn't have AVAudioSession; this is a non-issue for now. If a future Mac feature opens multiple game windows, audio routing becomes one-engine-many-windows — spec then.
