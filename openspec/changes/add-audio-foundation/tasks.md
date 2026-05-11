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

- [x] 4.1 Tests-first: translate `#### Scenario: Construction completion emits exactly one event`, `#### Scenario: Production cycle emits once per cycle`, `#### Scenario: Stall emits an event the tick the stall begins`, `#### Scenario: Stall resolution emits a resumed event once`, `#### Scenario: Carrier arrival emits once at the destination tick`, `#### Scenario: Tax interval emits a single event`, `#### Scenario: Bankruptcy warning emits once at deficit start`, and `#### Scenario: Game over emits exactly once` into failing tests in `CityCoreTests`. Confirm red. (12 red tests in `SystemEmissionsTests.swift`.)
- [x] 4.2 Implement to green: threaded `events: inout [WorldEvent]` through `advanceBuildings`, `apply`, `applyPlace`, `applyDemolish`, `runProductionSystem`, `runCarrierSystem`, `advanceCarriers`, `applyCarrierArrival`, `spawnCarriersFromProducers`, `runEconomySystem`. Each emits the spec'd events at the right point (state-transition edges for stall/bankruptcy/game-over so events fire once per transition).
- [x] 4.3 Tests-first for command-side events: added scenarios for `buildingPlaced`, `buildingDemolished`, `forestHarvested` to the `world-events` spec; tests in `SystemEmissionsTests.swift`. (Placement-rejected case is wired but not tested as a scenario — UI pre-validates today; we'll add a test if a rejection path becomes routable.)
- [x] 4.4 Implement to green: `apply(.harvestForest)` emits `forestHarvested`; `applyPlace` emits `buildingPlaced` on success and `placementRejected` on both rejection branches; `applyDemolish` emits `buildingDemolished`.
- [x] 4.5 Implement to green: `Events do not influence simulation state` invariant verified by the existing M2 `scenario: draining events does not affect determinism` test — drain vs discard both yield equal `World`s after 10 ticks.
- [x] 4.6 Refactor under a green bar: no duplicate emit-on-transition logic appeared more than twice; production stall/resume and economy warning/resolved each use distinct state variables, so a helper would be over-fitting. Skipped per scope.
- [x] 4.7 Verify `make test-scenarios` is clean for all `world-events` scenarios in this milestone. (All emission scenarios mapped; remaining unmapped scenarios belong to M5/M7+ milestones.)

## 5. M5 — CLI event log dump

- [x] 5.1 Tests-first: translate `#### Scenario: CLI writes event log when requested` and `#### Scenario: CLI omits event log by default` into tests in `CityCoreTests` (exercising `HeadlessRunner.runCollectingEvents`; subprocess-level CLI testing deferred until a CLI test target exists).
- [x] 5.2 Implement to green: `HeadlessRunner.runCollectingEvents(loadFrom:ticks:) -> (Summary, [WorldEvent])` in `CityCore`. `WorldEventJSON.swift` in `CLI/citybuilder-cli/` pattern-matches every `WorldEvent` case and serializes to a stable JSON array via `JSONSerialization` (pretty-printed, sorted keys). `main.swift` accepts `--events-out FILE` and writes events when set.
- [x] 5.3 Refactor under a green bar: `WorldEventJSON` lives only in `CLI/citybuilder-cli/`; `CityCore`'s `WorldEvent` stays Codable-free.
- [x] 5.4 Verify `make test-scenarios` is clean for the CLI scenarios. (Both M5 scenarios mapped to tests.)

## 6. M6 — Linux-clean validation and framework-free invariant

- [x] 6.1 Tests-first: added `scenario: citycore still linux-clean`, `scenario: no new framework imports in citycore` (sim-core delta), and `scenario: citycore still linux-clean after events land` (world-events spec). The `scenario: cli does not link audio` test lives in M7 with the CityAudio package.
- [x] 6.2 Implement to green: existing `scripts/check-no-apple-ui-imports.sh` passes on the post-M4 source tree. New `scripts/check-cli-no-audio.sh` does a static-scan of CLI source files for `import AVFoundation` / `import CityAudio` (pre-link validation; cheaper than a built-binary `otool -L` inspection). Wired into the Makefile (`make test-cli-no-audio`) and pre-commit (`check-cli-no-audio` hook, scoped to `CLI/citybuilder-cli/*.swift`).
- [ ] 6.3 If Swift Linux toolchain CI is configured: confirm `Packages/CityCore` builds and `swift test` passes on Linux. — DEFERRED (requires Linux CI runner if not present).

## 7. M7 — CityAudio package skeleton

- [x] 7.1 Created `Packages/CityAudio/` (Package.swift, `Sources/CityAudio/`, `Tests/CityAudioTests/`); registered `CityAudio` in `project.yml` as a dependency of `CitybuilderiOS` and `CitybuilderMac` only — `citybuilder-cli` does NOT depend on it. (xcodegen + Xcode build deferred to local hardware verification.)
- [x] 7.2 Tests for engine buses, lazy init, engine start, and `cli does not link audio` (source + project.yml static scan) in `PackageBoundaryTests.swift` and `AudioEngineTests.swift`.
- [x] 7.3 Implemented `AudioBus` (enum: `.music, .sfx, .loop, .ambient`) and `AudioEngine` wrapping `AVAudioEngine` with four `AVAudioMixerNode` buses connected to the main mixer. Engine is lazy — `isRunning` stays false until `start()` is called.
- [x] 7.4 Tests for volume change, global mute silences all buses, and volume settings persist. (Scenario `Master mute silences all buses` renamed to `Global mute silences all buses` to satisfy SwiftLint's inclusive-language rule.)
- [x] 7.5 Implemented `AudioSettings` with `UserDefaults` backing for `audio.musicVolume` / `audio.sfxVolume` / `audio.muted`. Per-bus volume setters and global mute on `AudioEngine`. (Settings → Engine binding lands in M11.)
- [x] 7.6 Refactor under a green bar. `make lint && make format` clean.

## 8. M8 — Manifest + bindings file formats and parsing

- [x] 8.1 Tests for `manifest has an entry for every audio file`, `manifest catches orphaned files`, `cc-by entries require attribution text`, `bindings reference manifest paths`, `orphan bindings fail ci` in `ManifestBindingsTests.swift`.
- [x] 8.2 `Manifest` and `Bindings` Codable DTOs in CityAudio with structural validators. `scripts/check-audio-manifest.swift` (Swift script, no new dependency) walks `Resources/Audio/` excluding `_candidates/`, parses manifest + bindings, and reports orphan files / missing attribution / orphan bindings. Wired into `make test-audio-manifest` and pre-commit (`check-audio-manifest` hook).
- [x] 8.3 Tests for `malformed bindings fail loudly at load` and `phase 1 has no loop bindings`. ("deleted file plays silently" and "unbound event is silent" are engine-runtime concerns — deferred to M9 where the cue dispatcher lands.)
- [x] 8.4 Implement to green: `Manifest.load(from:)` and `Bindings.load(from:manifest:)` throw `ValidationError` on invalid input. (Runtime engine fallback for missing/unbound files lands in M9.)
- [x] 8.5 Refactor under a green bar.

## 9. M9 — Cue dispatch and AudioCoordinator

- [x] 9.1 Tests for `bound event plays its cue`, `unbound event is silent`, `multiple cues pick one at random`, `coordinator dispatches every event`, `coordinator is main-actor safe`, and `deleted file plays silently` in `AudioCoordinatorTests.swift`.
- [x] 9.2 `AudioCoordinator` consumes `[WorldEvent]`, looks up bindings, and dispatches via an injected `CueDispatcher` closure (one-shot or loop). Multi-cue events pick one at random from the injected RNG. The dispatcher closure isolates AVAudioPlayerNode lifecycle from the coordinator — production wires it in M11; tests pass recorder closures.
- [x] 9.3 Tests for `repeat start does not stack` and `stop signal halts the loop`. (`phase 1 has no loop bindings` already mapped in M8.)
- [x] 9.4 Loop lifecycle keyed by `EntityID`: `consume(events:)` is idempotent for loop cues; explicit `stopLoop(for:)` removes the entity from `activeLoops`. The future engine-backed wiring (M11) will hold the actual `[EntityID: AVAudioPlayerNode]` map.

## 10. M10 — Music shuffle policy

- [x] 10.1 Tests for `single track loops with default gap` and `three tracks avoid recent repeats` in `MusicPlaylistTests.swift`.
- [x] 10.2 `MusicPlaylist` returns the bound track unchanged when only one is configured; multi-track mode shuffles with a no-repeat-within-last-two rule via injectable RNG. Default gap 30 s, overridable.

## 11. M11 — App shell integration (CityUI / app targets)

- [x] 11.1 `scenario: app targets link audio` already covered in M7 (`PackageBoundaryTests.swift`).
- [x] 11.2 `GameSession.audioEventConsumer: ([WorldEvent]) -> Void` optional. New public `step()` method drives one tick, applies the snapshot to the HUD, and forwards events to the consumer. The 10 Hz timer now drives `step()` (formerly the private `advance`). `AudioEventConsumer` typealias keeps CityUI independent of CityAudio — app shells pass `coordinator.consume(events:)`. App shell wiring (`CitybuilderiOSApp`, `CitybuilderMacApp`) is left for the app-side commit since those source files belong to the Apps/ targets and don't compile via swift-test.
- [x] 11.3 Tests in `CityAudioTests` (`SwiftUIViewTests.swift`) for `settings has audio sliders`, `settings exposes credits`, `every manifest entry appears in credits`, and `cc-by entries show attribution text`. Plus `GameSessionTests`: `session: forwards per-tick events to audio consumer`.
- [x] 11.4 `AudioSettingsView` (mute toggle + music/SFX sliders) and `CreditsView` (one row per manifest entry, attribution text for non-CC0) live in `CityAudio` so SwiftUI imports stay scoped to the audio package. Hooking into the platform Settings surface is an app-shell wiring detail deferred to the apps commit.

## 12. M12 — iOS audio session + interruption

- [x] 12.1 Tests for `audio session not activated at launch`, `player's music keeps playing` (macOS no-op surface), and `mac build links without audiosession` in `PlatformAudioSessionTests.swift`.
- [x] 12.2 `PlatformAudioSession` configures `AVAudioSession` category `.ambient` and registers an interruption observer inside `#if os(iOS) || os(tvOS) || os(visionOS)` guards. Forwards `.began` to `engine.stop()` and `.ended(shouldResume:)` to `engine.start()`.
- [x] 12.3 macOS path is empty (the same file's iOS-only block is compiled out). `AudioEngine` runs without any session configuration on Mac.
- [ ] 12.4 Phone-call integration test on hardware. — DEFERRED (requires physical iOS device).

## 13. M13 — iCloud sync of audio settings

- [x] 13.1 Tests for `volume change uploads to kv store`, `other device pulls latest volume`, `offline volume change queued`, `no icloud account does not block audio`, plus restated audio-playback variants `volume change syncs to another device` and `offline volume change is queued`.
- [x] 13.2 New `CloudKeyValueStore` protocol + `InMemoryCloudKeyValueStore` test double in `CityPersistence`. `AudioSettingsSync` mirrors `audio.musicVolume` / `audio.sfxVolume` / `audio.muted` between `UserDefaults` and the cloud store. Production NSUbiquitousKeyValueStore-backed implementation deferred to app-shell wiring.
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
