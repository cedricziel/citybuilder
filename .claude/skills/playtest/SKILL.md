---
name: playtest
description: Run a Citybuilder playtest session in the iOS Simulator as a player persona or as the UI auditor. Covers how to start a session, the one-simulator rule, how to read the screen, the allowed launch flags, the Apple TV and Mac limits, and the report formats. Use whenever a playtester agent plays or audits the real app.
---

# Playtest Citybuilder through the simulator

You play the real app, in the iOS Simulator, through the simulator control tool (`mcp__Claude_Code_iOS_Simulator__control`): `screenshot`, `tap`, `swipe`, `touch_path`, `touch2_path`, `text`, `press_key`, `button`, `rotate`, `open_url`, `launch`. That input is headless; it never takes over the owner's screen.

Never use computer use or desktop screen control. Never read the game's source code to decide how to play. A player cannot, and the point is to judge what a player sees. The UI auditor may read code for VoiceOver labels and Mac input handling only.

Load the `verify` skill too. It has the build and launch recipes this skill leans on.

## Start a session

1. **Pick the date and the screenshot folder.** `DATE=$(date +%F)`, then `mkdir -p playtests/$DATE-<persona>`. All paths below are relative to your worktree. If you have none, create one first (`git worktree add .claude/worktrees/playtest-<persona> -b playtest/<persona>-$DATE origin/main`) and work only there.
2. **Check the machine.** `df -h /` (a build needs several GB) and `uptime`. When the load average is far above the core count, other sessions are building; expect `launch` and `screenshot` to time out and retry after a minute instead of tapping blind.
3. **Claim the simulator** (next section).
4. **Build once, from committed code.** Use your own derived-data folder:
   ```bash
   xcodegen generate
   xcodebuild -project Citybuilder.xcodeproj -scheme CitybuilderiOS \
     -destination 'generic/platform=iOS Simulator' -derivedDataPath <scratch>/dd-ios CODE_SIGNING_ALLOWED=NO build
   ```
   The app is `<scratch>/dd-ios/Build/Products/Debug-iphonesimulator/Citybuilder.app`, bundle id `com.cedricziel.citybuilder`. If the orchestrator gave you a build path, use that and skip the build. Record the commit (`git rev-parse --short HEAD`) in the report.
5. **Boot your device** (see Devices), then install: `xcrun simctl install <UDID> <app>`.
6. **Launch.** The control tool's `launch` action installs and launches but cannot pass launch arguments, and it times out under load. Launch from the shell instead, with flags when the persona calls for them:
   ```bash
   xcrun simctl launch --terminate-running-process <UDID> com.cedricziel.citybuilder [-uiTest… flags]
   ```
   Then `attach` so the owner can watch if they want to, and take a `screenshot`. The title screen's Continue row loads asynchronously: wait about 3 s before you tap anything.
7. **Play** (see Read the screen). Take a screenshot at each key moment and save it with
   `xcrun simctl io <UDID> screenshot playtests/$DATE-<persona>/NN-short-name.png`.
8. **Write the report** (see Reports), then **shut down** (next section).

## One simulator at a time

The owner allows one simulator running across all agents; sessions run one after another.

1. Before you boot anything, run `xcrun simctl list devices booted`. If any device is booted and you did not boot it, stop: tell the orchestrator and wait. Never shut down, erase or install onto a device you did not boot or create.
2. Boot exactly one device, the one your persona is assigned.
3. When you finish, or give up, or fail, shut down what you booted: `xcrun simctl shutdown <UDID>`. If you created the device (the SE below), also `xcrun simctl delete <UDID>`.
4. Kill only the PIDs you started.

## Devices

Find a UDID by name: `xcrun simctl list devices available | grep '<name>'`.

| Role | Device | Portrait size in points |
|---|---|---|
| Small iPhone | `Playtest iPhone SE` (create it, below) | 375 × 667 |
| iPhone | iPhone 17 | 402 × 874 |
| Large iPhone | iPhone 17 Pro Max | 440 × 956 |
| iPad | iPad Pro 11-inch (M5) | 834 × 1210 |
| Apple TV | Apple TV 4K (3rd generation) | 1920 × 1080 |

- **The SE device does not exist by default.** Create it and delete it afterwards:
  `xcrun simctl create "Playtest iPhone SE" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-27-0`
- **Rotate** with the control tool: `rotate` with `direction` left or right, then take a `screenshot` and tap in that screenshot's frame, however it comes back. Rotate back before you shut down.
- **Boot and wait:** `xcrun simctl boot <UDID>` then `xcrun simctl bootstatus <UDID> -b`.

## Read the screen

- **Screenshot, act, screenshot.** Take a screenshot before every action and another after it. Sheet and panel transitions are slow: take a second screenshot before you decide a tap failed. Under machine load, a screen can lag by several seconds.
- **A stale screenshot is a lie.** Compare the status-bar clock in the screenshot with `date +%R`. If it is minutes behind, the host is starved and the simulator is not redrawing: stop, check `uptime` and `ps -Ao pcpu,pid,etime,args -r | head`, and wait. Do not play on frames you cannot trust. A hung test run from another session is the usual cause; tell the orchestrator and do not kill it.
- **Check the orientation first.** A device keeps the orientation it had when it last shut down, and the app follows it: a screenshot wider than tall is landscape. `rotate` is slow and sometimes needs two tries; after it, wait a few seconds and take two screenshots before you tap.
- **Coordinates are device points**, origin top-left. The screenshot you see may be scaled: its note says "displayed at W×H". Point = pixel × (device width in points ÷ displayed width). For a 750-px-wide SE screenshot that is × 0.5.
- **Know the tile pitch.** At zoom 1 one tile step in x is about (+32.5, +16) points. Tap a building with no tool armed and the inspector shows its anchor; from two such points you can work out where any tile is.
- **Pan** with `swipe` on empty map. **Zoom** with `touch2_path` (a pinch). Start swipes more than 4 points from a screen edge, or they become the system edge gestures.
- **Build:** tap a rail button (Town, Gather, Craft, Road, Demolish), tap a drawer tile, then tap the map. On iPhone and iPad a building that is not a road waits for a confirmation in the placement HUD before it commits.
- **Quote the screen.** When something confuses you, copy the on-screen text exactly into the report and name the screen it is on. Do not paraphrase a hint.
- **Never trust a tap you did not verify.** If the screenshot after the tap shows no change, say so; do not assume it worked.

## Launch flags

Every `-uiTest…` flag works in Debug builds only. A launch with any `-uiTest…` flag keeps its saves in a temporary folder of its own, hides the first-hour guide unless you add `-uiTestFirstSteps`, and, for the seeded worlds, gives the town a stocked store and funds, so its economy is not a fair start. A persona that judges the first hour or the economy starts a regular New Game from the title screen, with no flag.

**Allowed for personas** (they stage a state; the persona still plays by tapping):

| Flag | Stages |
|---|---|
| `-uiTestSeedTown` | The seed-0 island with four finished houses by the town center. With `-uiTestSeason`, `-uiTestCulture`, `-uiTestAge`. |
| `-uiTestSeedLived` | The town with farms and workshops working and residents in the houses. |
| `-uiTestSeedPort` | A Renaissance game with a player port. |
| `-uiTestSeedShore` | A port, a shipyard and a ship. |
| `-uiTestSeedArchipelago` | A new archipelago game on the largest map. |
| `-uiTestSeasons n` | Runs the seeded game `n` more seasons first, for a history. |
| `-uiTestSeason`, `-uiTestCulture`, `-uiTestAge` | Season, culture and age of a town seed. |
| `-uiTestCamera x,y,zoom` | Puts the camera on a tile. |
| `-uiTestStartGame` | Skips the title and starts at once. |
| `-uiTestFirstSteps` | Keeps the first-hour guide. |
| `-uiTestShowStats` | Shows frame rate and node counts. |

**Reserved for the UI auditor** (they reach a screen without playing): `-uiTestOpenStocks`, `-uiTestOpenStatistics`, `-uiTestShowcase`, `-uiTestPlace`, `-uiTestSelect`. A persona never uses them, because they do the player's work. The one exception is the veteran's Mac captures, where nobody can tap: there `-uiTestOpenStocks` and `-uiTestOpenStatistics` are allowed.

## The returning player's old save

Old saves are fixtures in `Packages/CityPersistence/Tests/CityPersistenceTests/Fixtures/saves/` (`v1_single_island.json` to `v10_single_island.json`, plus `v8_archipelago.json`); the current version is 11. Copy one into the simulator's Continue slot, then launch with **no** `-uiTest…` flag, so the app reads the real save folder:

```bash
DATA=$(xcrun simctl get_app_container <UDID> com.cedricziel.citybuilder data)
mkdir -p "$DATA/Library/Application Support/Citybuilder/saves"
cp <fixture> "$DATA/Library/Application Support/Citybuilder/saves/00000000-0000-0000-0000-000000000001.json"
```

Install the app first so the container exists. The title screen then offers Continue; the migration runs on load. Note what the town looks like and what the numbers are the moment it loads, before you touch it.

## Platform limits

**Apple TV.** The control tool drives a tvOS simulator. `screenshot` works, `press_key` with `left`, `right`, `up` and `down` moves focus, and `return` selects. It cannot send Menu, Play/Pause or touch-surface swipes, so anything that needs Back (leaving a sheet, the pause menu on the Menu button) is not reachable by hand; reach it with a launch flag, or review it from a screenshot without interacting, and say so in the report. Build with `-scheme CitybuilderTV` and the `verify` skill's Apple TV recipe; `xcrun simctl io <UDID> screenshot` also works.

**Mac.** Desktop input and computer use stay forbidden, so you cannot click the Mac app. You review it from window-only captures of a process you launched:

1. Build `CitybuilderMac` into your own derived-data folder (`CODE_SIGNING_ALLOWED=NO`).
2. `open -g -n <app> --args -Citybuilder.macLaunchFullscreen NO -ApplePersistenceIgnoreState YES <-uiTest… flags>`, then find your PID with `pgrep -f '<scratch>/dd-mac/.*/Citybuilder'`.
3. Find your window by that PID and capture only it: `xcrun swift .claude/skills/playtest/mac-window-id.swift <pid>` prints the window number; then `screencapture -x -o -l<windowid> shot.png`.
4. Reach each state with debug flags. Read the keyboard and pointer handling in `Packages/CityUI/Sources/CityUI` (`MacMapInput*.swift`, `View+Hotkey.swift`, `GameCommands.swift`) for shortcuts, hover and resizing.
5. `kill <pid>` when done.

Say in the report that Mac interaction was **not exercised by hand**: only captures and the code read.

## Reports

All reports are markdown, written in the player's voice, and ready to commit. Quote screen text exactly. Reference screenshots by relative path.

### Persona session report

`playtests/<date>-<persona>-<seed>.md`, with screenshots in `playtests/<date>-<persona>/`. Use `0` as the seed when the game has the default seed, and `random` when the player rolled one.

```markdown
# <Persona>: <one-line verdict> (<date>)

## Setup
Device and orientation, build commit, launch flags (or "none"), mode, difficulty, culture, seed, layout, how long you played (real minutes and in-game time), how the session ended.

## Timeline
Key moments, each with the in-game date or real minute and a screenshot link.

## What was fun
## Confusing or frustrating
Each item: what happened, the exact on-screen text, the screen it was on, a screenshot.

## Bugs
Each item: what you expected, what happened, exact steps to repeat from a fresh launch, severity, screenshot.

## Balance
Numbers you read from the screen (money, income, upkeep, prices, stocks, caps, population) and what they say about pacing.

## Top 3 changes
What this player wants most, in the player's words.

## Fun rating
N/10. Would you keep playing? Why or why not.
```

### UI audit reports

One report per device and orientation at `playtests/<date>-ui-audit/<device>-<orientation>.md`, and a matrix at `playtests/<date>-ui-audit/matrix.md`. Screenshots go in the same folder.

Each device report starts with the setup (device, orientation, build commit, flags, appearance, text size), then one section per screen (HUD, build rail and drawer, inspector, goals, research, standings, market, statistics, routes, hints and banners, pause, settings, save and load). Each section lists the checklist items it checked and every problem as:

```markdown
- **[S2] Short title.** Screen: <exact screen and state>. Checklist item: <item>. What is wrong, with the on-screen text. Screenshot: `<file>`.
```

Severity: **S1** blocks play or hides information the player needs; **S2** hurts reading or reaching something; **S3** polish. A screen with no problem still gets a line saying what was checked.

The matrix has one row per screen, one column per device and orientation, and a cell with `ok`, `S1`, `S2` or `S3` (the worst finding) linking to the report line, `n/a` where the screen does not exist there, and `not exercised` where the platform limits stopped you. Under it, list the three worst cross-device problems.

## Known quirks

Learned from the dogfood runs; they will save you time.

- **A loaded host makes everything late.** Under a load average above about 100, a tap shows its result 5 to 20 seconds later, `launch` times out, and the control tool's `screenshot` and `rotate` fail with "internal error" or "restarting after a crash". Wait for `uptime` to fall, retry, and fall back to `xcrun simctl io <UDID> screenshot <file>` and `xcrun simctl launch`, which keep working. Never queue several taps while the screen lags: they land on a different screen than you meant (a queued Start tap once flipped the New Game dialog to Scenario).
- **Save screenshots by file, and check them.** The control tool's screenshots are not written to disk. Use `xcrun simctl io <UDID> screenshot playtests/<date>-<persona>/NN-name.png` after the control screenshot shows the state you want, and open the file once to confirm it matches its name. Shrink big batches before you commit them (the repo should not carry 1 MB PNGs by the dozen).
- **Intro and transition frames.** Take a burst with a shell loop of `xcrun simctl io <UDID> screenshot` and a timestamp in each file name, started before the tap that triggers the transition, and run it in the background while you tap.
- **Text size, appearance and zoom.** `xcrun simctl ui <UDID> content_size <size>` (`large` is the default, `accessibility-extra-extra-extra-large` the largest) and `xcrun simctl ui <UDID> appearance light|dark` change a running app live. Put both back before you shut down. A pinch with two fingers is `touch2_path` with `points2`, for example fingers at x 101 and 301 moving to 151 and 251 at y 437, which zooms out by about half.
- **Debug launch flags need `simctl launch`.** `xcrun simctl launch --terminate-running-process <UDID> com.cedricziel.citybuilder -uiTestSeedTown -uiTestStartGame`. The `-uiTest…` seeds give the town about $9,999 of test funds, so do not judge the economy on them.
- **The first-run coachmark is a flag in the app's own defaults.** It shows once per install. `xcrun simctl uninstall` and install again to see it again.
- **Layout shifts between modes.** In the New Game dialog the Start button sits lower in Sandbox than in Scenario; take a screenshot before you tap it.
- **Remove files by literal path.** The shell refuses `rm` on a variable glob like `rm $DIR/*.png`; write the full absolute path, or leave the files.
