# Citybuilder

An Apple-exclusive city-builder ("Anno-like"). One island, tile-based construction, roads + warehouses, the Wood → Planks → Houses production chain, population needs, money balance, save/load, and iCloud sync. Universal across iPhone, iPad, and Mac with a 2.5D isometric world and optional 3D building portraits.

Bundle identifier: `com.cedricziel.citybuilder`
CloudKit container: `iCloud.com.cedricziel.citybuilder`

## Prerequisites

Install once via Homebrew:

```sh
brew install xcodegen pre-commit swiftlint swiftformat libimagequant jpeg-turbo
```

Xcode 26 or newer (Swift 6.3+) is required.

CI pins the tools whose versions change results: SwiftFormat and
SwiftLint (releases disagree on rules), pre-commit, libimagequant (it
quantizes every atlas PNG the art pipeline writes), jpeg-turbo and
XcodeGen:

| Tool          | Pinned version |
| ------------- | -------------- |
| SwiftFormat   | 0.63.1         |
| SwiftLint     | 0.65.1         |
| pre-commit    | 4.6.2          |
| libimagequant | 4.4.1          |
| jpeg-turbo    | 3.2.0          |
| XcodeGen      | 2.46.0         |

`scripts/ci/install-pinned-tools.sh` holds the pins; when you change
one there, update this table too.

Two limits:

- The Homebrew pins (libimagequant, jpeg-turbo, XcodeGen) check a
  digest; they can't install an older version. When a runner image's
  Homebrew moves a formula on, CI fails at the install step instead of
  quietly using the new version. Bump the version and digests in the
  script and here. For libimagequant, also re-render the atlases
  (`make sprites`) in the same PR, since it quantizes every atlas PNG.
- zlib is not pinned. Pillow links the zlib that the runner image (or
  your macOS) ships, and zlib decides the compressed PNG bytes. That
  doesn't affect verification: `make sprites-verify` compares renders
  within a tolerance, never byte for byte, and CI never re-renders.

## Quick start

```sh
make hooks          # install pre-commit, commit-msg, and pre-push hooks
make sprites-venv   # one-time: create .venv/sprites/ for the art pipeline (scripts/art)
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
│   ├── CityCore/            # pure-Swift simulation (no Apple UI imports); content packs in GameData/
│   ├── CityPersistence/     # save/load + CloudKit sync
│   ├── CityUI/              # shared SwiftUI views
│   ├── CityRender2D/        # SpriteKit isometric renderer
│   ├── CityRender3D/        # SceneKit building portraits
│   ├── CityAudio/           # AVFoundation engine, bindings, manifest, credits view
│   └── GameDataGen/         # build-time generator: YAML packs → CityCore Swift
├── scripts/
│   ├── check-coverage.sh
│   ├── check-scenario-coverage.swift
│   └── sweeps/              # release balance sweeps (PlayerBot)
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

### Balance sweeps

`scripts/sweeps/run-release-sweeps.sh` runs the long PlayerBot balance sweeps locally; see [`scripts/sweeps/README.md`](scripts/sweeps/README.md). Run one sweep at a time on the Mac: a full run takes hours and uses every core.

## Game data packs

Goods, buildings (recipes, storage, placement), cultures, techs, ages and house tiers live in YAML packs under `Packages/CityCore/GameData/packs/`. `Packages/CityCore/GameData/index.yaml` lists the packs in load order, as paths without `.yaml`. Each pack has an optional `defaults:` block of anchors, shared with YAML merge keys (`<<: *name`; keys written on the item win), and an ordered `items:` list. Every item has a `kind` (`Good`, `Building`, `Culture`, `Tech`, `Age`, `Tier`) and a kebab-case `id`. References may point into any pack: a building names the tech that unlocks it with `unlockedBy`, and the generator derives each tech's unlock list. In the same way, a good joins a house tier's needs with `neededBy: [merchants]`, so a pack adds demand without editing `core.yaml`. Field tables per kind are in the format reference in the game-data-codegen change ([`FORMAT.md`](openspec/changes/game-data-codegen/examples/FORMAT.md)).

`Packages/GameDataGen` (Swift, uses Yams, build-time only; CityCore never depends on it) validates every pack and writes Swift into `Packages/CityCore/Sources/CityCore/Generated/`. It also writes the player-visible pack text (names, units, blurbs, banners, order texts) into the String Catalog `Packages/CityUI/Sources/CityUI/Resources/GameData.xcstrings`, under keys like `building.grainFarm.name`; the generated Swift carries only the keys. It rejects unknown fields, unknown references, duplicate ids, prerequisite cycles, inert buildings, goods that nothing consumes (no recipe input, material, culture luxury or tier need) and pack files missing from the manifest. The generated files are committed; never edit them by hand.

To change content:

1. Edit a pack, or add one and list it in `index.yaml`.
2. Run `make gamedata`.
3. Write the German for any new or changed text in `GameData.xcstrings`. The generator writes only English: it keeps every German value and marks one `needs_review` when its English changed, which `make l10n-check` rejects until the German is reviewed and marked `translated`.
4. Commit the pack, the regenerated `Generated/` files and the catalog together.

`make gamedata-check` fails when the committed files differ from the packs. It runs in CI (macOS and Linux) and in the pre-commit hook when files under `GameData/` or `Generated/`, or `GameData.xcstrings`, are staged.

To review a content change, run `swift run --package-path Packages/GameDataGen gamedata-gen diff <ref>` from the repository root. It compares the packs at a git revision with the working tree, or with a second revision given as another argument. It prints one line per changed value (`Building sawmill: cost 120 → 130`), then the added and removed items. Anchors and merge keys are resolved first, so a changed anchor lists every item that merges it. Formatting, comments, key order and moving an item to another pack are not changes.

`.claude/settings.json` wires `scripts/gamedata-hook.sh` into Claude Code's Edit, Write and MultiEdit tools. It decides on the edited file's path alone:

- An edit to a file under `Generated/` is blocked, in shell, without building anything.
- After a `.yaml` edit under `GameData/`, the hook builds the generator in the same checkout as the pack, validates the packs, and reports any errors back to the agent.
- Edits to other files pass through without running anything.
- If the generator can't be built or run, the edit goes through.

The Bash tool isn't hooked, so `sed -i` or a shell redirect into `Generated/` gets past the hook. The pre-commit `gamedata-check` catches that drift before it is committed.

**Order matters.** Enum case order is load order: packs in manifest order, then items in file order. The order of `Good`, `Culture`, `Tech` and `Age` feeds the simulation (caravans, rival setup, research, age comparison), so reorder only on purpose. `BuildingKind` order only sets the build palette order. `Tier` order is also save format: a tier's raw value is its position, from 1.

**Code-backed buildings.** `effect: code` marks a building whose behaviour is written in Swift: houses, storage, roads, town center, port, shipyard, library, monument and signature buildings. A building with neither a recipe that produces goods nor `effect: code` is rejected as inert. A new `effect: code` building compiles but does nothing until its Swift behaviour exists.

**Sprites.** A new building, culture or age also needs sprite catalog entries; `SpritesStyleCatalogTests` (CityRender2D) fails until they exist. CI also builds CityCore, CityUI and CityRender2D with `Packages/GameDataGen/Tests/Fixtures/fixture-pack.yaml` to prove a pack compiles without Swift edits. Run the same check locally with `scripts/check-gamedata-fixture-build.sh`.

**Editor support.** Each YAML file starts with a `# yaml-language-server: $schema=...` comment pointing at `Packages/CityCore/GameData/schema/pack.schema.json` or `index.schema.json`. VS Code with the Red Hat YAML extension, or any editor using yaml-language-server, validates and autocompletes from it. Xcode has no YAML schema support; generator errors name the pack file, line and item.

**Determinism.** Adding or reordering content changes simulation output. Regenerate the fixture output and mention the change in the PR:

```sh
SWIFT_DETERMINISTIC_HASHING=1 xcrun swift run --package-path Packages/CityCore DeterminismFixture
SWIFT_DETERMINISTIC_HASHING=1 xcrun swift run --package-path Packages/CityCore DeterminismFixture 36000
```

A pure refactor must leave the output byte-identical. CI compares macOS and Linux output on the same commit.

## Adding or changing a sprite

Buildings, people, animals and ships are pre-rendered 3D recipes in
`Tools/IsoKit`; terrain, roads and their transition tiles come from the
SVG generators in `scripts/art`. No sprite comes from an
image-generation model. `Resources/Sprites.style/world.md` is the style
bible: the camera, light rig and finish set every sprite shares. The
`iso-sprite-authoring` skill covers recipes in detail.

1. **Write or change the recipe.** A building is a `Recipe` in
   `Tools/IsoKit/Sources/IsoKitCore/Recipes/`: its cell, construction
   stages, any moving part (sails, a saw) and the parts it builds from
   the shared finishes. `make sprites-check` (`isokit check`) checks
   that every recipe fits its cell and follows the recipe rules,
   without a GPU.
2. **Write the brief.** Each sprite kind has
   `Resources/Sprites.style/catalog/<id>.md` with `source = "isokit"`
   (or `"svg"`) in its front matter and these sections:
   - `## Function`: what the sprite does in the game
   - `## Visual identity`: what it looks like
   - `## Sprites`: one `` - `<sprite name>` `` line per sprite it owns
   - `## Recipe`: the recipe, its cell and its frame counts
3. **Render**: `make sprites` re-renders every atlas PNG. It needs a
   Mac GPU and `rsvg-convert`, and no network. Renders vary slightly
   between runs, so commit only the PNGs of the sprites you changed
   and restore the rest.
4. **Verify**: `make sprites-verify` compares fresh renders with the
   committed PNGs within a tolerance, then runs the content gate.
5. **Show it.** A significant visual change gets a before and after on
   a Claude Design canvas before its PR, and the PR links it under
   `## Design`.

If the sprite animates, add its entry to `SpriteAnimation.entry(for:)`
in `Packages/CityRender2D/Sources/CityRender2D/SpriteAnimation.swift`.
The scene's reconciler picks a new sprite up without `IsoWorldScene`
changes.

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
   case name to a `Cue` (file, bus, optional `volume`, optional `loop`,
   optional `kindFilter`, optional `action`).
4. Run `make test-audio-manifest` to verify the file is tracked and any
   CC-BY attribution is present. Pre-commit and CI run the same check.

#### Per-building loops

For a sound that should play while a building is operating (e.g. a
sawmill loop), bind one `start` cue on `productionResumed` and one
`stop` cue on `productionStalled`, both filtered to the building kind:

```json
"productionResumed": [
  { "file": "loop/sawmill.caf", "bus": "loop", "loop": true, "kindFilter": "sawmill" }
],
"productionStalled": [
  { "action": "stop", "kindFilter": "sawmill" }
]
```

`AudioCoordinator` keys loops by `EntityID`, so multiple sawmills each
get their own player. When a building leaves the world (demolished,
save reloaded without it), the per-tick `WorldSnapshot` push tears down
the loop — no extra teardown binding needed.

#### Ambient bed

The `ambient` bus runs continuously while the simulation is alive. Add
a top-level `ambient` section paralleling `music`:

```json
"ambient": {
  "tracks": [ { "file": "ambient/forest-birds.caf" } ]
}
```

`AudioStack` starts the first track as a loop cue on the `ambient` bus
on the first non-empty `[WorldEvent]` it receives.

#### Music ducking

Every SFX cue briefly pulls the `music` bus down ~6 dB then ramps it
back over ~300 ms. The behaviour is on by default; users can toggle it
via `AudioSettings.musicDucksUnderSFX`. Loop and ambient cues do NOT
trigger ducking — they're continuous and would hold the music down.

The cap on audio files is 3 MB (enforced by pre-commit) — large enough
for a ~1.5 MB sawmill loop without forcing low-bitrate transcodes.

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

Goods icons are hand-authored SVG on a 24-point grid, drawn by
`scripts/art/goods_icons.py` and rendered at @1x and @2x into
`Resources/Kit.atlas`.

1. **Draw the icon**: add the good's shapes to `GLYPHS` and its colours
   to `PALETTES` in `scripts/art/goods_icons.py`, in the shared style
   (natural colours, lit from the upper left, dark outline).
2. **Write the brief**:
   `Resources/Sprites.style/catalog/good-<rawValue>.md` with
   `source = "svg"`, and `Function`, `Visual identity`, `Sprites`
   and `Recipe` sections. Then run `make sprites`, and
   `make sprites-svg-verify` to check the committed PNGs.
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

## Touch placement

On iOS you place buildings without arming the palette first: long-press a tile (0.4 s), pick a building from the menu, nudge the ghost with the four iso arrows, then tap the checkmark to place it (or the cross to cancel). Nothing is spent until the checkmark. The menu follows the palette's rules: obsolete buildings are hidden, locked ones are disabled with the research they need, and entries you cannot afford or place on that tile say why. An **Actions** button beside the inspector opens the same menu, and a one-time hint teaches the long-press.

The palette still works: arming a building and tapping a tile starts the same pending placement. Road and Demolish keep painting tile by tile, because confirming every road tile would be miserable. macOS keeps palette, hover and click-to-place; the long-press gesture, menu and HUD are iOS-only. The pending placement is session state and is never saved. Costs and materials are described under [Material costs](#material-costs).

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
(`overlay-waiting-materials.png` in `Resources/Icons.atlas/`)
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

## iCloud sync

Saves sync through the CloudKit private database of container `iCloud.com.cedricziel.citybuilder`. The production client is `CloudKitDatabaseClient` (`Packages/CityPersistence/Sources/CityPersistence/CloudKitDatabaseClient.swift`). Nothing in the apps calls it yet; turning sync on is a later change.

Each game is one `CitySave` record named after its game ID, with fields `gameID` (String), `body` (Asset), and `currentDevice` (String). `recordName` must be queryable. The full schema and deploy steps are in [`Packages/CityPersistence/CloudKitSchema.md`](Packages/CityPersistence/CloudKitSchema.md). Deploy the schema to the production environment in the CloudKit console before TestFlight or App Store builds can sync.

Unit tests use the in-memory fake `InMemoryCloudKitClient` and need no iCloud account.

The live tests in `Packages/CityPersistence/Tests/CityPersistenceTests/CloudKitLiveTests.swift` talk to the container's development environment. They are skipped unless `CITYBUILDER_CLOUDKIT_TESTS=1` is set, and CI never sets it. Each test uses a fresh game ID and deletes its record afterwards.

The live tests need a test host signed with the iCloud entitlement and a signed-in iCloud account. A plain `swift test` binary has no entitlement, so `CITYBUILDER_CLOUDKIT_TESTS=1 xcrun swift test --package-path Packages/CityPersistence` does not reach CloudKit. The repo has no entitled test host yet, so there is currently no command that runs them.

## CI

The CI workflow runs `pre-commit run --all-files`, `make generate`, builds all targets, runs every `swift-testing` suite, and enforces `make test-coverage` (CityCore line ≥ 80% / branch ≥ 70%, diff-cover green) plus `make test-scenarios` (every spec `#### Scenario:` maps to a test).

## Releasing

release-please cuts releases (`.github/workflows/release-please.yml`, `release-please-config.json`, `.release-please-manifest.json`). Conventional Commits on `main` keep a release PR open. Merging it tags `vX.Y.Z`, creates a GitHub release, updates `CHANGELOG.md`, and bumps `MARKETING_VERSION` in `project.yml` (the line marked `# x-release-please-version`).

The `testflight` job then builds that tag on a `macos-26` runner, iOS (IPA, iPhone + iPad) and macOS (PKG) in parallel. It signs with fastlane match, using App Store profiles from the private `cedricziel/certificates` repo, and uploads to the internal TestFlight group "Internal". There is no external beta. The build number is `git rev-list --count HEAD`.

To re-upload an existing tag, run the release-please workflow manually and set the `tag` input (e.g. `v0.2.0`).

The workflow needs these repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`, `MATCH_PASSWORD`, `MATCH_KEYCHAIN_PASSWORD`, `MATCH_DEPLOY_KEY` (read-only deploy key on `cedricziel/certificates`), and `RELEASE_PLEASE_TOKEN` (a PAT, so the release PR triggers CI).

To run the lanes locally, use the Ruby version in `.ruby-version`, run `bundle install`, and copy `fastlane/.env.default` to `fastlane/.env` with the App Store Connect API key and match password filled in.

```sh
bundle exec fastlane ios build          # signed build, no upload (same for mac)
bundle exec fastlane ios release        # build + upload to TestFlight (same for mac)
bundle exec fastlane bootstrap_signing  # create/refresh match certs and profiles for iOS, tvOS, macOS
```

`bootstrap_signing` writes to the certificates repo; pass `force:true` to regenerate. tvOS has a match profile and an App Store Connect platform, but no app target yet.

## License

TBD.
