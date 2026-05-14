## 1. M1 — Event payload: kind on stall/resume (CityCore)

- [x] 1.1 Tests-first: translate `#### Scenario: Stall event carries building kind` and `#### Scenario: Resume event carries building kind` into failing tests in `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: add `kind: BuildingKind` to `WorldEvent.productionStalled` and `WorldEvent.productionResumed`. Update emit sites in `Systems.swift` to read `building.kind` from the producer. Update existing tests that destructure the cases.
- [x] 1.3 Refactor under a green bar. Run `make test`.

## 2. M2 — Bindings schema: stop action, kindFilter, ambient section (CityAudio)

- [x] 2.1 Tests-first: translate `#### Scenario: Stop cue halts the active loop`, `#### Scenario: Kind filter restricts a cue to matching events`, and `#### Scenario: Ambient section round-trips through JSON` into failing tests.
- [x] 2.2 Implement to green: extend `Bindings.Cue` with `action: CueAction = .start` (`start | stop`) and `kindFilter: BuildingKind?`. Add `Bindings.AmbientSection` paralleling `MusicSection`. Update `Bindings.allFilePaths` to include ambient tracks.
- [x] 2.3 Refactor under a green bar.

## 3. M3 — Loop teardown via snapshot diff (CityAudio + CityUI)

- [x] 3.1 Tests-first: translate `#### Scenario: Snapshot diff stops loops for missing entities` into a failing test in `CityAudioTests` (use a recorder dispatcher and a hand-built snapshot fixture).
- [x] 3.2 Implement to green: `AudioCoordinator.consumeSnapshot(_:)` iterates `activeLoops` and calls `stopLoop(for:)` for ids not in `snapshot.buildings`. Idempotent.
- [x] 3.3 Tests-first: `session: forwards snapshot to audio after tick` in `CityUITests`.
- [x] 3.4 Implement to green: `GameSession` gains an optional `snapshotConsumer: (WorldSnapshot) -> Void`. `step()` calls it after `audioEventConsumer`. App shells wire `coordinator.consumeSnapshot`.

## 4. M4 — Music ducker (CityAudio)

- [x] 4.1 Tests-first: translate `#### Scenario: SFX cue ducks the music bus`, `#### Scenario: Music recovers after release window`, and `#### Scenario: Loop and ambient cues do not duck music` into failing tests.
- [x] 4.2 Implement to green: `MusicDucker` wraps a `CueDispatcher`. On every dispatched cue, if `cue.bus == .sfx`, schedule a 30 ms ramp from current music volume to `currentMusic * 0.5`, then a 300 ms ramp back. Reentrant — overlapping SFX restart the release timer, no stacking.
- [x] 4.3 Implement to green: `AudioSettings.musicDucksUnderSFX: Bool` (default true). `AudioStack` wraps the engine dispatcher in `MusicDucker` when the flag is on; bypasses when off.

## 5. M5 — Coordinator routes start/stop actions + kindFilter (CityAudio)

- [x] 5.1 Tests-first: translate `#### Scenario: ProductionResumed starts the per-kind loop`, `#### Scenario: ProductionStalled stops the active loop`, and `#### Scenario: Kind-filtered cue ignores non-matching producers` into failing tests.
- [x] 5.2 Implement to green: `AudioCoordinator.consume(events:)` evaluates `cue.kindFilter` against the event's `kind` (when present); skips on mismatch. For `cue.action == .stop`, look up the entity's active loop and call `stopLoop(for:)`; no playback initiated.

## 6. M6 — Ambient bed lifecycle (CityAudio)

- [x] 6.1 Tests-first: translate `#### Scenario: Ambient track starts on first non-empty events`, `#### Scenario: Ambient track loops indefinitely`, and `#### Scenario: Empty ambient section is a no-op` into failing tests.
- [x] 6.2 Implement to green: `AudioStack` constructs an ambient `MusicPlaylist`-shaped helper from `bindings.ambient?.tracks`. On the first `consume(events:)` with a non-empty array, starts the ambient track as a loop cue on `.ambient` bus. Idempotent.

## 7. M7 — Carrier arrival one-shot (CityAudio + bindings)

- [x] 7.1 Tests-first: translate `#### Scenario: Carrier arrival plays a one-shot` into a failing test using a recorder dispatcher.
- [x] 7.2 Implement to green: nothing in CityAudio code changes (the existing coordinator handles this). Add the binding entry to the shipped `bindings.json` once Phase 2 content lands (M9).

## 8. M8 — Pre-commit policy: raise audio file size cap

- [x] 8.1 Update `.pre-commit-config.yaml` `check-added-large-files` arg to `--maxkb=3072`. Document the audio exception alongside.
- [x] 8.2 Verify `pre-commit run check-added-large-files --all-files` passes.

## 9. M9 — Phase 2 content (audition + transcode)

- [x] 9.1 Audition Phase 2 candidates. Pick: one sawmill loop, one lumberjack chop loop, one ambient birdsong / forest bed, one carrier-arrival clink. — **PLACEHOLDER**: ffmpeg-synthesized stand-ins; swap for curated CC0/CC-BY assets before ship.
- [x] 9.2 Transcode picks. Music/loop sources to `.caf` IMA4 (or `.m4a` HE-AAC for tracks > 1 MB). Target < 3 MB each. — All four assets are `.caf` IMA4, total ~350 KB.
- [x] 9.3 Place under `Resources/Audio/loop/`, `Resources/Audio/ambient/`, `Resources/Audio/sfx/`. Add manifest entries (with attribution text for the CC-BY saw loop). Add bindings: `productionResumed`/`productionStalled` per kind, `carrierArrived`, and the `ambient.tracks` array.
- [x] 9.4 Verify `make test-audio-manifest` passes; verify the credits view shows the CC-BY attribution string. — Manifest passes; CC-BY attribution UI verification deferred (placeholders are CC0; swap in a real CC-BY asset to exercise that path).

## 10. M10 — Polish + docs

- [x] 10.1 README: extend the "Adding a new audio cue" section with the loop + ambient + ducking subtleties.
- [x] 10.2 Final `make test`, `make lint`, `make format`. Confirm pre-commit clean across every commit on the branch.
- [ ] 10.3 Hardware audition on Mac + iPhone + iPad. — DEFERRED (requires devices).
- [x] 10.4 Update `design.md` of `add-audio-foundation` (archived) — no, do not touch the archive. Any retrospective notes belong in this change's design.md.
