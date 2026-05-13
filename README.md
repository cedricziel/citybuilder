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
make hooks          # install pre-commit, commit-msg, and pre-push hooks
make sprites-venv   # one-time: create .venv/sprites/ for the AI sprite pipeline
make generate       # regenerate Citybuilder.xcodeproj from project.yml
make test           # run all swift-testing suites
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

Sprite art is produced by the AI pipeline driven by the natural-language
catalog under `Resources/Sprites.style/`. To add a new animated terrain
or building:

1. **Edit the style bible if needed.** Most additions stay within the
   register already declared in `Resources/Sprites.style/world.md`
   (palette, projection, outline). If your new sprite needs a new
   palette role, add it there first. Edits to `world.md` invalidate
   every cache entry (intentional — bumping a global property
   regenerates everything).
2. **Author the catalog entry.** Create
   `Resources/Sprites.style/catalog/<id>.md` declaring sections:
   - `## Function` — what the sprite does in-world
   - `## Visual identity` — silhouette, palette anchors, distinctive
     details
   - `## Sheet` — `Grid: N cols × M rows.` then one `- (r, c):
     <atlas-filename>` line per cell (use `spare` for unused cells)
   - `## Animation` — sequences of `(r, c)` arrows for each loop;
     frames MUST be placed in adjacent cells per the sprite-style
     catalog spec.
3. **Add the catalog entry to `SpriteAnimation.entry(for:)`** in
   `Packages/CityRender2D/Sources/CityRender2D/SpriteAnimation.swift`
   if the sprite animates (`frameCount`, `timePerFrame`, `loop`).
4. **Regenerate**: `make sprites` (needs `OPENAI_API_KEY`; ~$0.04 per
   sprite kind, ~2 min wall-clock at 4-way concurrency). Cache hits
   on unchanged inputs are free; only the new/edited entry will
   actually call the API.
5. **Visually review** the regenerated PNG under
   `Resources/<Category>.atlas/`. If the result needs tightening,
   iterate on the catalog entry's prose and re-run `make sprites`.
6. **Commit** the new `Resources/Sprites.style/catalog/<id>.md`, the
   new `Resources/Sprites.style/_sheets/<id>.png`, and the produced
   atlas PNG(s). CI runs `make sprites --offline` (no API key) and
   verifies committed atlas PNGs reproduce byte-for-byte from the
   committed catalog + sheets.

The scene's reconciler picks the new sprite up automatically — no
`IsoWorldScene` changes are needed.

If playtest reveals visible animation flicker on a particular sprite,
opt that catalog entry into the two-pass escape hatch by setting
`two-pass: true` in its YAML front matter; the pipeline then runs a
second `/v1/images/edits` call against the pass-1 base cell as
reference to lock pixel coherence for the operational frames at 2×
the API cost.

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

### Spatial audio

The `loop` bus is routed through an `AVAudioEnvironmentNode` so per-building
loop cues attenuate and pan based on the camera's position. Music, SFX, and
ambient stay 2D — those buses connect to the main mixer directly.

- **Cue dispatch carries an optional `TileCoordinate`.** The coordinator
  resolves it from the event's primary entity against the last snapshot
  pushed via `AudioStack.consumeSnapshot(_:)`. Non-entity events
  (`taxesCollected`, `gameOver`) dispatch with `position: nil`.
- **`spatialize: Bool?` on `Bindings.Cue`** overrides routing per cue.
  Default behaviour: spatialized iff `bus == .loop`. Set
  `"spatialize": false` in the JSON to keep a loop cue 2D (e.g. an
  ambient bed that's intrinsically non-positional).
- **Listener position updates at 1 Hz** from the renderer's
  `IsoWorldScene.cameraListener`. Per-frame writes audibly jitter on
  ProMotion devices; the 1 Hz throttle smooths panning without losing
  responsiveness for typical camera moves. App shells wire this to
  `AudioStack.setListenerPosition(_:)`, which writes through to the
  environment node's listener slot.
- **Tile-to-meter mapping.** `AVAudioEnvironmentNode` thinks in metres;
  the engine treats one tile as one metre, so `TileCoordinate(x, y)`
  becomes `AVAudio3DPoint(x, 0, y)`.
- **Default distances:** reference 4 tiles (full volume), max 32 tiles
  (silent beyond). Tunable via `AudioSettings.spatialReferenceDistance`
  and `.spatialMaxDistance`, exposed under the **Advanced** disclosure
  of the audio settings panel.
- **Accessibility / mono output.** The "Spatial audio" toggle in audio
  settings bypasses the environment node entirely (loop → main directly);
  intended for hearing-impaired players or mono-output setups. The
  toggle is a session-level switch: changing it triggers a graph rebuild
  with a brief audible glitch. iCloud-synced across devices.

## Island HUD

The HUD has three layers that read off the `WorldSnapshot`:

- **Money + Population badges** — global state, always visible.
- **Island name badge** — derived from `WorldSnapshot.camera.centerTile()`
  through `WorldSnapshot.island(at:)`. When the camera enters an island
  the name appears; over open water it sticks to the last island so the
  player keeps a reference frame. It only goes blank when the camera
  has never been on any island since the world loaded.
- **Stocks row** — one chip per good with non-zero stock OR non-zero
  capacity on the current island. Producer-internal stockpiles (sawmill
  / lumberjack hut output buffers) are excluded; only warehouse, port,
  and shipyard buffers count.

Island names are deterministic per world seed. The picker draws from a
64-entry table (`IslandNameTable.entries` in `CityCore`) keyed by the
island's bounding-box center and `IslandID`. Names persist across
save/load via the `Island.name` Codable field.

### Adding a new good icon

1. **Author the catalog entry.** Create
   `Resources/Sprites.style/catalog/good-<rawValue>.md` with the four
   required sections (`Function`, `Visual identity`, `Sheet`,
   `Animation`). Use a `Grid: 1 cols × 1 rows.` sheet — goods are
   single-cell static icons. Follow the existing
   `good-wood.md` / `good-planks.md` / `good-food.md` shape; their
   front-matter overrides `sheet_size = "256x256"` and `cell_grid =
   "1x1"` so the cell downsamples cleanly to the canonical 24×24 HUD
   size with nearest-neighbour resampling.
2. **Regenerate**: `make sprites`. Commit the produced
   `Resources/Icons.atlas/good-<rawValue>.png` plus the new
   `Resources/Sprites.style/_sheets/good-<rawValue>.png`.
3. **Extend `Good`** in
   `Packages/CityCore/Sources/CityCore/Goods.swift` with the matching
   raw value. The HUD reads icons via `GoodIconLoader.image(for:)`,
   which maps `good.rawValue` → `Bundle.main.url(forResource:
   "good-<rawValue>", withExtension: "png")`.

## Material costs

Every building (except road and town center) declares a `materialCost: [Good: Int]` in `BuildingCatalog`. Placement is gated on per-island availability — `World.canPlace(_:at:)` consults the island's goods-buffer stockpiles (warehouse + port + shipyard + town center) and rejects with `.insufficientMaterials([Good: Int])` when any good is short. `applyPlace` then deducts materials deterministically from the nearest goods buffers (Manhattan distance ascending, tiebreak by `EntityID`).

The starter loop:

| Building       | Material cost           |
| -------------- | ----------------------- |
| Town Center    | free (player starts with one) |
| Road           | free                    |
| Lumberjack Hut | 2 wood                  |
| Sawmill        | 4 wood + 1 plank        |
| Warehouse      | 2 wood + 6 planks       |
| House          | 4 planks                |
| Port           | 8 wood + 6 planks       |
| Shipyard       | 12 wood + 8 planks      |

World-gen seeds each island's town center with **4 wood + 2 planks** — enough to place exactly one lumberjack hut (2 wood) and start the chain. Tune the recipe numbers in `BuildingCatalog.specs` for a one-commit balance pass.

When a build tool is armed, the HUD's `CostBreakdownView` renders one chip per required good showing `have/need`. Goods where `have < need` paint red so the player sees the shortfall before clicking.

## Construction stalls

When the player places a building whose recipe is partially met, the
placement still goes through: `canPlace` allows it as long as the
island either holds the missing goods or has an operational producer
that makes them. The building enters `.constructing` +
`.waitingForMaterials`. `ticksSincePlacement` does NOT advance until
the recipe is satisfied — construction time only accrues while the
substate is `.actively`.

Carriers pick up the slack. Each producer's tick prioritizes a waiting
construction site on its island over a warehouse. A delivery to a
waiting site bumps the site's `materialsDelivered[good]`; once every
good in the recipe is covered, the site flips to `.actively` and emits
`constructionStarted`.

The ghost preview reflects the supply situation per good:

- **`.ok`** (default color) — the island already has enough in goods
  buffers.
- **`.queueable`** (orange) — the island is short, but a producer on
  the island makes the good. Placement is allowed; the building will
  queue.
- **`.blocked`** (red) — the island is short and no producer supplies
  the good. Placement is rejected.

A waiting construction site renders a small clock-face badge
(`overlay-waiting-materials.png` in `Resources/Buildings.atlas/`)
floating above the building tile. The badge disappears the moment the
site flips to `.actively`.

## Display

iPad locks fullscreen: `UIRequiresFullScreen = true` in the bundled
`Info.plist` opts the app out of Split View, Slide Over, and Stage
Manager. The iso-projected world doesn't read well at multitasking
widths; if a future change wants Stage Manager support it lifts that
key explicitly.

Mac launches fullscreen by default. The first `.onAppear` calls
`NSWindow.toggleFullScreen(nil)` via `MacFullscreenTracker`. If the
user exits fullscreen (Cmd-Ctrl-F, green-button click, View → Exit
Full Screen) the tracker's `willExitFullScreenNotification` observer
writes `false` to `Citybuilder.macLaunchFullscreen` in
`UserDefaults.standard`; the next launch reads that and comes up
windowed. Re-entering fullscreen flips the flag back to `true`. The
preference is per-machine — Mac and iPad have different fullscreen
semantics so it's intentionally not iCloud-synced.

## Title screen and New Game

The app launches into a typographic title screen (`TitleScreenView`)
rather than a live world. From there the player picks:

- **Continue** — visible only when a save exists. Loads the newest
  save (looked up via `SaveStore.mostRecentSave()`, a pure file-system
  scan — no `World` decode).
- **New Game…** — opens a modal dialog with a `WorldLayout` segmented
  picker (Single Island / Archipelago) and a seed mode (Default = 0,
  Random with captured value, or Custom decimal). `Start` is disabled
  until the seed parses; tapping `Start` does NOT re-roll a random
  seed.
- **Settings** — opens the audio + credits surface in a sheet
  (Cmd-, also opens the standard Mac `Settings` scene).
- **Quit** — macOS only. iOS has no Quit affordance per platform
  conventions.

`GameSession` construction is deferred until the player commits a
world. The `TitleScreenHost` injects a `GameSessionFactory` closure
that captures audio; the host watches `committedSession` and swaps in
`CityRootView` once it appears.

Defaults preserve the MVP play experience: hitting `Start` without
changing anything in the new-game dialog produces the same world the
zero-arg `World.newGame()` does (`.singleIsland`, seed `0`).

## Pause and pause menu

Pressing **ESC** (or **Cmd-.** on Mac) toggles a hard pause: while
paused, `GameSession.step()` short-circuits — no `World.tick()`, no
new snapshot, no audio events forwarded. Carriers freeze mid-path,
SFX stop firing. The audio engine is untouched so the music loop
keeps playing; you can sit in the menu without dead air.

The pause menu appears as a modal sheet over the frozen world:

- **Resume** — un-pauses (same as ESC).
- **Save Game** — writes the current world to the save slot via
  `SaveStore.save(_:gameID:)`. Status row shows "Saved" or
  "Couldn't save: …" for ~2 seconds.
- **Settings** — opens the existing settings sheet.
- **Quit to Title** — auto-saves silently and returns to the title
  screen. Hidden until `add-title-screen-and-new-game` lands.
- **Quit** — Mac only. `NSApplication.shared.terminate(nil)`.

The HUD's top-right cluster shows a pause/play button next to the
gear; its glyph swaps with `session.isPaused`. Tap or ESC — same
result.

## CI

The CI workflow runs `pre-commit run --all-files`, `make generate`, builds all targets, runs every `swift-testing` suite, and enforces `make test-coverage` (CityCore line ≥ 80% / branch ≥ 70%, diff-cover green) plus `make test-scenarios` (every spec `#### Scenario:` maps to a test).

## License

TBD.
