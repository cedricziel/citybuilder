## 1. M1 — TickResult migration (CityCore, no events yet)

- [x] 1.1 Tests-first: translate `#### Scenario: Tick returns TickResult`, `#### Scenario: TickMetrics still observable`, and the existing `#### Scenario: Tick time instrumented` (from archived `simulation-core`) into failing tests in `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: introduce `public struct TickResult: Sendable, Equatable { let metrics: TickMetrics; let events: [WorldEvent] }`, change `World.tick() -> TickResult`, return `TickResult(metrics:..., events: [])`. (Events list stays empty in this milestone.) Update every call site in the monorepo (`HeadlessRunner`, `CityUI.GameSession`, all tests) with the one-line change `world.tick()` → `world.tick().metrics`.
- [x] 1.3 Refactor under a green bar: confirm no caller still expects `TickMetrics` directly. Verify `make test` passes. (CityCore 69, CityUI 27, CityRender2D 32, CityRender3D 6, CityPersistence 16 — all green.)
- [x] 1.4 Verify `make test-scenarios` is clean for `simulation-core` scenarios touched in this milestone. (TickResult / TickMetrics scenarios mapped; M3/M6 simulation-core scenarios are expected unmapped pending their milestones.)

## 2. M2 — WorldEvent enum + emission machinery (CityCore)

- [x] 2.1 Tests-first: translate `#### Scenario: Event enum is exhaustive over MVP capabilities`, `#### Scenario: Event is not Codable`, `#### Scenario: TickResult exposes events`, `#### Scenario: Empty tick yields empty event list`, `#### Scenario: Events not in World`, `#### Scenario: Save round-trip preserves nothing about events`, and `#### Scenario: Draining events does not affect determinism` into failing tests in `CityCoreTests`. Confirm red.
- [x] 2.2 Implement to green: introduce `public enum WorldEvent: Equatable, Sendable` with the cases listed in the spec. Add `var primaryEntityID: EntityID?` and `var caseOrdinal: Int` as public computed properties. (Deviation from design D1: `pendingEvents` is NOT stored on `World` — instead `tick()` uses a local `[WorldEvent]` and M4 will thread `inout` into each system. This aligns with the spec scenario `Events not in World`, which forbids storing such a property; design.md will be updated in M15 to match.)
- [x] 2.3 Refactor under a green bar: emit helper deferred to M4 — the inout-threaded buffer means systems will append directly via `events.append(...)`, no `World.emit(_:)` helper is needed. (Revisit if M4 reveals duplication.)

## 3. M3 — Deterministic event ordering

- [x] 3.1 Tests-first: translate `#### Scenario: Stable ordering inside a single tick`, `#### Scenario: Replay produces identical event sequences`, `#### Scenario: Replay event sequences match`, and `#### Scenario: Replay world state remains byte-identical` into failing tests in `CityCoreTests`. (Stable-ordering test exercises the sort directly with synthetic events; the three replay tests use real ticks — empty event lists today, meaningful once M4 emission lands.)
- [x] 3.2 Implement to green: apply the decorate-sort-undecorate stable sort by `(primaryEntityID ?? .max, caseOrdinal, insertion-index)` at the end of `tick()`. (Deviation from spec wording: "byte-identical when Codable-encoded" replaced with `World == World` equality, matching the archived `scenario: determinism under replay` test, because `Dictionary`-keyed fields encode as iteration-order arrays; structural equality is the operational invariant.)
- [x] 3.3 Verify `make test-scenarios` is clean for the ordering scenarios.

## 4. M4 — Emission inside existing systems (CityCore)

- [ ] 4.1 Tests-first: translate `#### Scenario: Construction completion emits exactly one event`, `#### Scenario: Production cycle emits once per cycle`, `#### Scenario: Stall emits an event the tick the stall begins`, `#### Scenario: Stall resolution emits a resumed event once`, `#### Scenario: Carrier arrival emits once at the destination tick`, `#### Scenario: Tax interval emits a single event`, `#### Scenario: Bankruptcy warning emits once at deficit start`, and `#### Scenario: Game over emits exactly once` into failing tests in `CityCoreTests`. Confirm red.
- [ ] 4.2 Implement to green: add `emit(.constructionCompleted(...))` inside `advanceBuildings()` where state flips. Add `emit(.productionCycleCompleted(...))` after the output deposit in `runProductionSystem()`. Add `emit(.productionStalled(...))` / `emit(.productionResumed(...))` gated on transitions of `ProductionProgress.isStalled`. Add `emit(.carrierArrived(...))` inside `applyCarrierArrival`. Add `emit(.taxesCollected(...))` and `emit(.upkeepPaid(...))` inside `runEconomySystem` on the interval ticks. Add `emit(.bankruptcyWarning(...))` and `emit(.bankruptcyResolved(...))` on balance-sign transitions. Add `emit(.gameOver)` on the tick `gameOver` flips to true.
- [ ] 4.3 Tests-first for command-side events: translate scenarios for `buildingPlaced`, `buildingDemolished`, `forestHarvested`, and `placementRejected` into failing tests. (These are not currently in the spec list — they belong to `world-events` spec's `Events emitted by each existing system` requirement.) Confirm red.
- [ ] 4.4 Implement to green: add the corresponding `emit(...)` calls inside `apply(_ command:)` and its helpers (`applyPlace`, `applyDemolish`).
- [ ] 4.5 Implement to green: add `Events do not influence simulation state` invariant — write the scenario test and confirm `World` byte-identical with events-drained vs events-discarded.
- [ ] 4.6 Refactor under a green bar: extract any duplicate "emit on transition" logic into a small helper if it appears more than twice.
- [ ] 4.7 Verify `make test-scenarios` is clean for all `world-events` scenarios in this milestone.

## 5. M5 — CLI event log dump

- [ ] 5.1 Tests-first: translate `#### Scenario: CLI writes event log when requested` and `#### Scenario: CLI omits event log by default` into failing tests in `CityCoreTests` (or a new `CLITests` target if not present). Confirm red.
- [ ] 5.2 Implement to green: add an `--events-out FILE` flag to `HeadlessRunner` (or to the CLI main, depending on where flag parsing lives). Define a presentation-only `WorldEventJSON` helper in the CLI target that pattern-matches `WorldEvent` and serializes to JSON. CityCore stays Codable-free for events.
- [ ] 5.3 Refactor under a green bar: confirm `WorldEventJSON` lives in the CLI target only (no leakage into CityCore).
- [ ] 5.4 Verify `make test-scenarios` is clean for the CLI scenarios.

## 6. M6 — Linux-clean validation and framework-free invariant

- [ ] 6.1 Tests-first: translate `#### Scenario: CityCore still Linux-clean`, `#### Scenario: No new framework imports in CityCore`, and `#### Scenario: CLI does not link audio` into failing checks (the last is a shell-driven CI check using `otool -L`).
- [ ] 6.2 Implement to green: confirm `scripts/check-no-apple-ui-imports.sh` passes on the post-M4 CityCore source tree. Add `scripts/check-cli-no-audio.sh` that builds the CLI and asserts AVFoundation is not linked; wire into `make ci`.
- [ ] 6.3 If Swift Linux toolchain CI is configured: confirm `Packages/CityCore` builds and `swift test` passes on Linux. — DEFERRED (requires Linux CI runner if not present).

## 7. M7 — CityAudio package skeleton

- [ ] 7.1 Add `Packages/CityAudio/` with `Package.swift`, `Sources/CityAudio/`, and `Tests/CityAudioTests/`. Register in `project.yml`; depend on `CityCore` and link `AVFoundation`. Run `make generate` and confirm both app targets link `CityAudio`; confirm CLI does NOT.
- [ ] 7.2 Tests-first: translate `#### Scenario: Engine has four buses`, `#### Scenario: Engine lazy-initializes on first cue`, `#### Scenario: Engine starts on first cue`, and `#### Scenario: CLI does not link audio` into failing tests. Confirm red.
- [ ] 7.3 Implement to green: introduce `AudioBus` (enum: `.music, .sfx, .loop, .ambient`), `AudioEngine` wrapping `AVAudioEngine` with four `AVAudioMixerNode` buses connected to main mixer. Engine init is lazy (struct holds a closure; first `play(_:)` triggers `AVAudioEngine.start()`).
- [ ] 7.4 Tests-first: translate `#### Scenario: Volume change applies within one render cycle`, `#### Scenario: Master mute silences all buses`, and `#### Scenario: Volume settings persist` (locally, no iCloud yet) into failing tests. Confirm red.
- [ ] 7.5 Implement to green: per-bus volume setters, master mute. Persistence wires through an `AudioSettings` observable model with UserDefaults backing.
- [ ] 7.6 Refactor under a green bar. Run `make lint && make format`.

## 8. M8 — Manifest + bindings file formats and parsing

- [ ] 8.1 Tests-first: translate `#### Scenario: Manifest has an entry for every audio file`, `#### Scenario: Manifest catches orphaned files`, `#### Scenario: CC-BY entries require attribution text`, `#### Scenario: Bindings reference manifest paths`, and `#### Scenario: Orphan bindings fail CI` into failing tests in `CityAudioTests` plus a failing shell test for `scripts/check-audio-manifest.sh`. Confirm red.
- [ ] 8.2 Implement to green: define `Manifest` and `Bindings` DTOs in CityAudio with `Codable` from JSON. Write `scripts/check-audio-manifest.sh` (bash, no new dependency) that walks `Resources/Audio/` and validates both files. Wire into `make lint` and pre-commit.
- [ ] 8.3 Tests-first: translate `#### Scenario: Malformed bindings fail loudly at load`, `#### Scenario: Deleted file plays silently`, and `#### Scenario: Unbound event is silent` into failing tests. Confirm red.
- [ ] 8.4 Implement to green: `AudioEngine.load(manifest:bindings:)` throws on schema-invalid input; missing-file lookup at play time returns silently with debug log.
- [ ] 8.5 Refactor under a green bar.

## 9. M9 — Cue dispatch and AudioCoordinator

- [ ] 9.1 Tests-first: translate `#### Scenario: Bound event plays its cue`, `#### Scenario: Multiple cues pick one at random`, `#### Scenario: Coordinator dispatches every event`, and `#### Scenario: Coordinator is main-actor safe` into failing tests. Confirm red.
- [ ] 9.2 Implement to green: `AudioCoordinator.consume(events:)` walks the array, looks up bindings, and dispatches to the engine. For one-shots, allocate a transient `AVAudioPlayerNode` per cue or pool a small set. For multiple bindings on one event, pick one with a non-deterministic RNG (the audio layer's, not CityCore's).
- [ ] 9.3 Tests-first: translate `#### Scenario: Repeat start does not stack`, `#### Scenario: Stop signal halts the loop`, and `#### Scenario: Phase 1 has no loop bindings` into failing tests. Confirm red.
- [ ] 9.4 Implement to green: loop lifecycle keyed by `EntityID`; map `[EntityID: AVAudioPlayerNode]` for active loops. Loops are inert in Phase 1 bindings, but the machinery is in place.

## 10. M10 — Music shuffle policy

- [ ] 10.1 Tests-first: translate `#### Scenario: Single track loops with default gap` and `#### Scenario: Three tracks avoid recent repeats` into failing tests. Confirm red.
- [ ] 10.2 Implement to green: `MusicPlaylist` type. Single-track mode loops the same file with the configured gap. Multi-track mode uses a no-repeat-within-last-two shuffle. Test with deterministic RNG seed inside the test (the audio RNG is configurable for testability even though production is non-deterministic).

## 11. M11 — App shell integration (CityUI / app targets)

- [ ] 11.1 Tests-first: translate `#### Scenario: App targets link audio` into a build-config test (or a shell-script equivalent). Confirm the build flag is set; if not, fail loudly.
- [ ] 11.2 Implement to green: extend `GameSession` to accept an injected `AudioCoordinator` (optional, default nil for the headless test paths). In `step()`, forward `result.events` to the coordinator. Wire actual `AudioCoordinator` construction in `CitybuilderiOSApp` and `CitybuilderMacApp` SwiftUI App entry points.
- [ ] 11.3 Tests-first: translate `#### Scenario: Settings has audio sliders` and `#### Scenario: Settings exposes credits` into failing tests in `CityUITests` (view-model assertions or snapshot tests, depending on existing test style). Confirm red.
- [ ] 11.4 Implement to green: add `AudioSettingsView` (volume sliders, mute toggle) wired to `AudioSettings`. Add `CreditsView` reading `manifest.json`. Hook both into the platform Settings surface.

## 12. M12 — iOS audio session + interruption

- [ ] 12.1 Tests-first: translate `#### Scenario: Player's music keeps playing`, `#### Scenario: Audio session not activated at launch`, `#### Scenario: Phone call pauses audio`, `#### Scenario: Phone call ends resumes audio`, and `#### Scenario: Mac build links without AudioSession` into failing tests. Confirm red.
- [ ] 12.2 Implement to green: `iOSAudioSession` helper compiled in only on iOS (via `#if os(iOS) || os(iPadOS)`). Sets category `.ambient` on first cue. Subscribes to `AVAudioSession.interruptionNotification` and forwards `began` / `ended(shouldResume:)` to the engine.
- [ ] 12.3 Implement to green: macOS target compiles `iOSAudioSession` out entirely; `AudioEngine` operates without a session.
- [ ] 12.4 Phone-call integration test on hardware. — DEFERRED (requires physical iOS device).

## 13. M13 — iCloud sync of audio settings

- [ ] 13.1 Tests-first: translate `#### Scenario: Volume change uploads to KV store`, `#### Scenario: Other device pulls latest volume`, `#### Scenario: Offline volume change queued`, and `#### Scenario: No iCloud account does not block audio` into failing tests in `CityPersistenceTests`. Confirm red.
- [ ] 13.2 Implement to green: extend the existing CloudKit KV-store layer to add `audio.musicVolume`, `audio.sfxVolume`, `audio.muted`. Hook `AudioSettings` change observers to the upload path.
- [ ] 13.3 Cross-device sync round-trip test. — DEFERRED (requires two devices on the same iCloud account).

## 14. M14 — Initial content binding (Phase 1)

- [ ] 14.1 Audition the staged candidates in `Resources/Audio/_candidates/` (three OGA medieval tracks, Kenney UI pack, OGA wood/metal pack, Magnesus forest birds, SDFY coin pickup). Pick: one music track, one UI-click, one placement thunk, one construction chime, one coin tick, one game-over sting.
- [ ] 14.2 Transcode picked sources to ship formats: music to `.m4a` AAC ~96 kbps (target < 3 MB); SFX to `.caf` IMA4 (target < 50 KB each). Use `afconvert` (ships with macOS, no new dependency).
- [ ] 14.3 Place files under `Resources/Audio/` in their bus-named subfolders (`music/`, `ui/`, `construction/`, `economy/`). Author `Resources/Audio/manifest.json` with full license metadata. Author `Resources/Audio/bindings.json` mapping the six events to these files.
- [ ] 14.4 Verify `scripts/check-audio-manifest.sh` passes on the new content.
- [ ] 14.5 Remove `Resources/Audio/_candidates/` from version control (move outside the working tree if we want to keep auditioning, but not in the repo).
- [ ] 14.6 Sanity-check on real hardware: launch the app, place a building, hear the thunk. — DEFERRED (requires Mac and at least one iOS device).

## 15. M15 — Polish, docs, and CI

- [ ] 15.1 Update `README.md` with a section on the audio system: where bindings/manifest live, how to add a new sound, how the credits screen is fed.
- [ ] 15.2 Document the `--events-out` CLI flag.
- [ ] 15.3 Verify `make ci` includes `scripts/check-audio-manifest.sh` and `scripts/check-cli-no-audio.sh`.
- [ ] 15.4 Final `make lint && make format`. Confirm pre-commit, commit-msg, and pre-push hooks pass on every commit in the branch.
- [ ] 15.5 Verify `make test-scenarios` is clean for `world-events`, `audio-playback`, `simulation-core`, `platform-shells`, and `icloud-sync`.
- [ ] 15.6 Profile a 5-minute play session on Mac with audio enabled. Capture CPU and audio-render-cycle stats. Document baseline so Phase 2 (loops) has a regression comparison. — DEFERRED (requires interactive profiling).
