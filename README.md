# Citybuilder

An Apple-exclusive city-builder ("Anno-like"). One island, tile-based construction, roads + warehouses, the Wood → Planks → Houses production chain, population needs, money balance, save/load, and iCloud sync. Universal across iPhone, iPad, and Mac with a 2.5D isometric world and optional 3D building portraits.

Bundle identifier: `com.cedricziel.citybuilder`
CloudKit container: `iCloud.com.cedricziel.citybuilder`

## Prerequisites

Install once via Homebrew:

```sh
brew install xcodegen pre-commit swiftlint swiftformat
```

Xcode 26 or newer (Swift 6.3+) is required.

## Quick start

```sh
make hooks       # install pre-commit, commit-msg, and pre-push hooks
make generate    # regenerate Citybuilder.xcodeproj from project.yml
make test        # run all swift-testing suites
```

Open `Citybuilder.xcodeproj` in Xcode and pick `CitybuilderiOS` or `CitybuilderMac`.

## Repository layout

```
.
├── project.yml              # XcodeGen single source of truth
├── Makefile                 # canonical entry points
├── .pre-commit-config.yaml  # hook definitions
├── .swiftlint.yml
├── .swiftformat
├── Apps/
│   ├── CitybuilderiOS/      # iOS + iPadOS app shell
│   └── CitybuilderMac/      # macOS app shell
├── CLI/
│   └── citybuilder-cli/     # headless simulation runner
├── Packages/
│   ├── CityCore/            # pure-Swift simulation (no Apple UI imports)
│   ├── CityPersistence/     # save/load + CloudKit sync
│   ├── CityUI/              # shared SwiftUI views
│   ├── CityRender2D/        # SpriteKit isometric renderer
│   ├── CityRender3D/        # SceneKit building portraits
│   └── CityAudio/           # AVFoundation engine, bindings, manifest, credits view
├── scripts/
│   ├── check-coverage.sh
│   └── check-scenario-coverage.swift
└── openspec/                # change proposals and capability specs
```

The generated `*.xcodeproj` / `*.xcworkspace` are gitignored — edit `project.yml`, run `make generate`.

## Development workflow

1. Pick a task from the active OpenSpec change at `openspec/changes/add-mvp-foundation/tasks.md`.
2. **Tests first.** Translate the relevant `#### Scenario:` blocks from `openspec/changes/add-mvp-foundation/specs/<capability>/spec.md` into failing `swift-testing` tests. Confirm `make test` is red.
3. Implement the smallest change that makes the test green.
4. Refactor under a green bar.
5. Run `make lint && make format` before committing.
6. Use Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`, `build:`, `ci:`); the `commit-msg` hook enforces this.

## Adding a new animated sprite

The renderer animates sprites through one catalog. To add a new animated
terrain or building:

1. Add the per-frame artwork helpers to `scripts/generate-sprites.swift`,
   then emit the frames as `terrain-<kind>-<index>.png`,
   `building-<kind>-operational-<index>.png`, or
   `building-<kind>-constructing-<index>.png`.
2. Run `swift scripts/generate-sprites.swift` and commit the new PNGs
   under `Resources/Sprites/`.
3. Add an entry to `SpriteAnimation.entry(for:)` in
   `Packages/CityRender2D/Sources/CityRender2D/SpriteAnimation.swift`
   declaring `frameCount`, `timePerFrame`, and `loop` (`.forever` for
   idle, `.progress` for construction).

The scene's reconciler picks the new entry up automatically — no
`IsoWorldScene` changes are needed.

## Adding a new audio cue

The audio layer plays cues in response to `WorldEvent` cases emitted by
`World.tick()`. To bind a new sound:

1. Drop the audio file under `Resources/Audio/<bus>/<name>.<ext>` where
   `<bus>` is one of `music`, `sfx`, `loop`, or `ambient`. Preferred
   formats: `.caf` (IMA4) for SFX, `.m4a` (AAC ~96 kbps) for music loops.
   Use `afconvert` (ships with macOS) — no Homebrew dependency needed.
2. Add an entry to `Resources/Audio/manifest.json` with the file path,
   title, author, source URL, and license. For non-CC0 licenses, also
   include the `attribution` string the credits screen will display.
3. Add a binding in `Resources/Audio/bindings.json`: map the `WorldEvent`
   case name to a `Cue` (file, bus, optional `volume`, optional `loop`).
4. Run `make test-audio-manifest` to verify the file is tracked and any
   CC-BY attribution is present. Pre-commit and CI run the same check.

The CLI runner (`citybuilder-cli`) does **not** link the audio package —
the headless path stays Foundation-only. Use `--events-out events.json`
to dump the full `[WorldEvent]` log from a run for scenario assertions
or replay validation.

Audio audition workflow:

- Free CC0 / CC-BY assets can be staged under `Resources/Audio/_candidates/`
  for local listening; the folder is gitignored and never ships.
- Pick winners, transcode with `afconvert`, drop into the appropriate
  bus subfolder, add the manifest + binding entries, and the engine
  picks them up on next launch.

## CI

The CI workflow runs `pre-commit run --all-files`, `make generate`, builds all targets, runs every `swift-testing` suite, and enforces `make test-coverage` (CityCore line ≥ 80% / branch ≥ 70%, diff-cover green) plus `make test-scenarios` (every spec `#### Scenario:` maps to a test).

## License

TBD.
