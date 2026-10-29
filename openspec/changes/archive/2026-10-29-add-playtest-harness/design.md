## Context

Personas must play the real app, so the interface is the simulator control tool (`control` with `screenshot`, `tap`, `swipe`, `touch_path`, `text`, `press_key`, `button`, `rotate`, `launch`, `open_url`). The `verify` skill already knows how to build and launch Citybuilder. The debug launch flags (`-uiTestSeed…`, `-uiTestSeasons`, `-uiTestStartGame` and the rest) already set up states without performing player actions.

## Decisions

### D1. Personas are agent files; shared rules live in one skill

Each persona file holds only what makes the persona different: background, goals, playstyle, patience, what it notices, the quit rule, its device. Everything procedural (boot, launch, read the screen, the report format) lives in `.claude/skills/playtest/SKILL.md`, and each persona loads that skill and `verify`. Alternative considered: put the procedure into every agent file. Rejected, because eight copies drift.

### D2. One simulator at a time, enforced by procedure

The owner allows one running simulator across all agents. A session boots its device, plays, and shuts it down; the next session starts after. The skill says to check `xcrun simctl list devices booted` first and to wait or stop if another device is booted, and never to shut down a device the session did not boot. A personal build per session goes to the session's own derived-data folder, as in `verify`.

### D3. Launch flags set the stage, taps do the playing

A tester may launch with any existing `-uiTest…` flag that sets a state: seed, culture, age, season, seasons, camera, a lived town, a port. A tester may not use a flag that acts for the player. Today's flags that place a building (`-uiTestPlace`, `-uiTestSelect`) and the showcase flags are reserved for the UI auditor, which needs to reach a state, not play. The test reads the flags from `UITestSeed` so a rename breaks the build of the skill, not a session.

### D4. Screens are read by screenshot, then act

Every action is followed by a screenshot before the next decision; sheet transitions are slow, so a second screenshot comes before a tap is judged failed. Coordinates are device points from the control tool, and the skill records the screenshot-to-point factor per device. Alternative considered: the accessibility tree. The control tool does not expose it, so VoiceOver labels are checked from the code.

### D5. Devices

| Persona | Device | Orientation |
|---|---|---|
| newcomer | iPhone 17 | portrait |
| optimizer | iPad Pro 11-inch (M5) | landscape |
| builder | iPad Pro 11-inch (M5) | portrait |
| trader | iPhone 17 | landscape |
| veteran | Mac | window captures only |
| chaos | iPhone SE (3rd generation) | portrait |
| returning | iPhone 17 Pro Max | portrait |

The simulator list has no SE, so the skill creates one with `xcrun simctl create` and deletes it at the end of the session.

### D6. Platform limits, verified

- **Apple TV:** the control tool drives a tvOS simulator. `screenshot`, `press_key` (arrow keys, return) and `button` work, and arrow keys move focus. The skill records which remote buttons it cannot send.
- **Mac:** desktop input and computer use stay forbidden. The auditor and the veteran review the Mac app from window-only captures (`screencapture -l<windowid>`) of a process they launched and identified by PID, with debug flags to reach each state, plus a read of the keyboard and pointer handling in the code. Reports say that Mac interaction was not exercised by hand.

### D7. The test guards the files, not the games

`PlaytestKitTests` reads the agent and skill files and checks what can silently drift: the eight names, the frontmatter, the tool list, the device per persona, the skill's required sections, and that every `-uiTest…` flag the skill cites exists in the app sources. It cannot judge a playtest.

## Risks / Trade-offs

- [Sessions are slow and cost tokens] → The skill sets the minimum play time and the quit rules, and the personas run on `sonnet` at medium effort.
- [Tap coordinates break across devices] → The skill tells the agent to screenshot first, to read points from the screenshot's reported scale, and gives known anchors per device.
- [A persona acts like an engineer] → Each file says to write feedback in the player's voice, and the report format has no section for code.
- [Two agents boot simulators at once] → The booted-device check comes first in every session, and the owner serialises the sessions.
- [The simulator state leaks between sessions] → Each session uses `-uiTest…` flags only for staging; a session without flags uses the real save folder of its own simulator, which the skill erases on shutdown (`simctl erase` of the device the session created or booted).
