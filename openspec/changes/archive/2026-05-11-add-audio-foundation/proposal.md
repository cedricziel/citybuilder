## Why

The archived MVP foundation deferred audio with a single line: *"Music & SFX: deferred to post-MVP. Architecture should expose a `WorldEvent` stream that an audio layer can subscribe to later."* That stream does not exist — `World.tick()` returns only `TickMetrics`. The game is silent across all 13 capabilities. An "Anno-like" without audio feels inert in a way that no amount of sprite animation will fix; the goal of this change is to put the foundation in place so we can ship sound now (music + the smallest useful SFX set) and grow into per-building loops and positional audio later without re-architecting.

We have already auditioned the asset landscape: CC0 music (OpenGameArt medieval pack), CC0 UI/impact SFX (Kenney), and CC0 ambient loops (Freesound) cover most of the medium tier. A few categories (medieval factory hum, cart-on-cobble) have no clean CC0 source — the design must allow events to ship without a sound and treat "missing binding" as a normal state, not a bug.

## What Changes

- Add a new `world-events` capability owned by CityCore that defines a `WorldEvent` enum (placement, construction complete, carrier arrival, production cycle, tax tick, upkeep tick, bankruptcy warning, game over, etc.) and changes `World.tick()` to return a `TickResult` aggregating the existing `TickMetrics` plus a transient `[WorldEvent]` list. Events are not Codable, not persisted, and produced deterministically for a given input sequence.
- Add a new `CityAudio` Swift package (Apple-only, depends on AVFoundation) under `Packages/CityAudio`. The package exposes an `AudioCoordinator` that consumes per-tick events, an `AudioEngine` built on `AVAudioEngine` with four mixer buses (music / sfx / loop / ambient), a JSON `bindings.json` mapping `WorldEvent` cases to one-or-many sound files, and a JSON `manifest.json` listing every audio asset with title / author / source URL / license.
- Add a new `audio-playback` capability covering the engine, bindings format, manifest format, missing-binding behavior, per-bus volume control, music shuffle policy, loop lifecycle keyed by `EntityID`, and the credits view fed by the manifest.
- Modify `simulation-core` to add the event-stream requirement on top of the existing tick contract (no existing scenario changes; `TickMetrics` is now nested in `TickResult.metrics`).
- Modify `platform-shells` to add iOS audio-session configuration (`.ambient` category so the player's own music keeps playing alongside) and interruption handling (pause audio on phone calls / Siri).
- Modify `icloud-sync` to add three CloudKit key-value entries — `audio.musicVolume`, `audio.sfxVolume`, `audio.muted` — synced across devices.
- Add a `Resources/Audio/` asset folder (curated CC0 starter set), a `Resources/Audio/manifest.json` (license metadata), a `Resources/Audio/bindings.json` (event → file mapping), and a CI lint script `scripts/check-audio-manifest.sh` that fails if any bundled audio file lacks a manifest entry.
- Add a SwiftUI **Credits & Licenses** view in CityUI that renders the manifest. Reachable from the existing Settings surface.
- The headless `citybuilder-cli` does NOT link `CityAudio`. The CLI continues to run with Foundation only, can consume `[WorldEvent]` from `TickResult` for scenario assertions and event-log dumps, and never loads AVFoundation.
- Initial binding scope (Phase 1 content): one music track on shuffle of one, a UI-click SFX for build palette, a placement-thunk SFX, a construction-complete chime, a coin tick on tax interval, and a game-over sting. All other event types have a defined `WorldEvent` case but no bound sound — they play silent until enriched in a future change.

## Capabilities

### New Capabilities
- `world-events`: Stable, deterministic `WorldEvent` enum and the `TickResult` aggregate that surfaces them out of CityCore without breaking the framework-free invariant.
- `audio-playback`: AVAudioEngine-backed playback layer (four mixer buses, JSON bindings, JSON manifest, per-bus volume, missing-binding silence, music shuffle, loop lifecycle, credits view contract).

### Modified Capabilities
- `simulation-core`: `tick()` return type expanded from `TickMetrics` to `TickResult { metrics, events }`. Determinism contract extended: the event sequence is byte-identical under replay.
- `platform-shells`: iOS audio session category + interruption handling; macOS no-op.
- `icloud-sync`: Three new key-value entries for audio settings (volume sliders + mute), synced across devices.

## Impact

- **CityCore** — new `WorldEvent` enum, new `TickResult` struct, `tick()` signature change, event emission added to each system function (production cycle, carrier arrival, economy tax/upkeep/bankruptcy, building state transitions, command application). No save-format change (events are transient). Determinism preserved by emitting in a stable order (sort by `EntityID` before flushing).
- **CityAudio (new package)** — new `Packages/CityAudio/` registered in `project.yml`. Depends on Foundation + AVFoundation only. Linked by `CitybuilderiOS` and `CitybuilderMac`. NOT linked by `citybuilder-cli`. New tests in `CityAudioTests` for bindings parsing, manifest parsing, missing-binding lookup, engine bus configuration (mock engine).
- **CityUI** — `GameSession`'s tick loop forwards `TickResult.events` to an injected `AudioCoordinator`. New `CreditsView` rendering the manifest. New volume sliders + mute toggle in Settings.
- **CityPersistence / icloud-sync** — three new KV-store keys synced via the existing CloudKit machinery. No record-type change, no migration.
- **Resources/Audio/** — initial starter pack (≤ ~8 MB total): one music track (m4a/AAC ~2 MB), six SFX one-shots (CAF/IMA4, < 50 KB each). Asset bundle grows; nowhere near a size concern.
- **Resources/Audio/manifest.json** + **bindings.json** — new authored files. Manifest is the source of truth for the credits screen; bindings is the routing table.
- **CLI runner** — gains an optional `--events-out FILE` flag that writes the `[WorldEvent]` log as JSON. Useful for scenario assertions and CI replay validation.
- **CI** — new `make check-audio-manifest` step (cheap shell script). No new build-time tool dependency: `afconvert` ships with macOS, no Homebrew install required.
- **Performance** — `AVAudioEngine` cold-start is ~100 ms; engine is lazy-initialized on first cue rather than at app launch. Event emission per tick is O(events emitted); typical tick produces 0–5 events, well within the existing 5 ms per-tick budget.
- **Determinism** — events are sorted by `EntityID` before being appended to `TickResult.events`. Same save + same input sequence → byte-identical `World` AND byte-identical event log. Replay tests gain a second equality check.
- **iOS audio session** — `.ambient` category by default (the player's music keeps playing); flips to `.playback` only if they explicitly enable in-game music. Phone-call interruption pauses the engine; resumption restores it.
- **macOS** — no audio session; AVAudioEngine alone is sufficient.
- **No save-format change.** No new Homebrew dependency. No third-party runtime dependency.
