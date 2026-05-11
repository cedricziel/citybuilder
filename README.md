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
│   └── CityRender3D/        # SceneKit building portraits
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

## CI

The CI workflow runs `pre-commit run --all-files`, `make generate`, builds all targets, runs every `swift-testing` suite, and enforces `make test-coverage` (CityCore line ≥ 80% / branch ≥ 70%, diff-cover green) plus `make test-scenarios` (every spec `#### Scenario:` maps to a test).

## License

TBD.
