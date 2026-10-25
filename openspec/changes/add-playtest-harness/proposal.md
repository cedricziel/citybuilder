## Why

The owner wants design feedback from players who are not the people building the game. Each agent that plays gets a persona (a first-timer, a min-maxer, a relaxed builder, a trader, a veteran, a chaos tester, a returning player) and a device, and reports what it felt. The first-hour work (#185) and the mid-game pacing work (#186) were both tuned against a scripted bot, and a bot cannot tell us that a hint is unreadable on an iPhone SE or that a drawer tile is too small to hit.

Agents in this repo have so far worked without the UI. This change lets personas play the real app in the iOS Simulator, through the simulator control tool: screenshot, tap, swipe, text, launch. That input is headless and never takes over the owner's screen. Computer use and desktop screen control stay forbidden.

## What Changes

- **Seven player personas** as project agents, `.claude/agents/playtester-<slug>.md`: `newcomer`, `optimizer`, `builder`, `veteran`, `trader`, `chaos`, `returning`. Each has a background, goals, playstyle, patience, what it notices and a quit rule. Each plays a long session (30 to 45 minutes of real play at least, or until the persona would quit), takes screenshots, quotes on-screen text and judges look, feel, readability and touch ergonomics as well as the rules.
- **A device per persona**, spread across the matrix: iPhone portrait (newcomer), iPad landscape (optimizer), iPad portrait (builder), iPhone landscape (trader), Mac from captures only (veteran), small iPhone (chaos), Pro Max (returning).
- **An eighth agent, `playtester-ui-auditor`**, that is not a persona. It reviews every screen on every device size against a checklist and writes one report per device plus a cross-device matrix.
- **A project skill, `.claude/skills/playtest`**: how to start a session, the one-simulator rule, how to read the screen reliably, which debug launch flags a tester may use, how to boot a device and rotate it, the Apple TV and Mac limits, and the report formats.
- **A test** that keeps the personas, their devices, the skill and the launch flags it cites in step with each other.

Out of scope: any harness that plays for the agent (an interactive CLI, synthetic or accessibility input), changes to the game, and running the personas in CI.

## Capabilities

### New Capabilities
- `playtesting`: the personas, the UI auditor, the skill and the report format.

### Modified Capabilities
- (none)

## Impact

- **New files**: eight agent definitions, one skill, a sample newcomer report and a sample UI-audit report with their screenshots under `playtests/`.
- **CityUI tests**: one suite, `PlaytestKitTests`, that reads the agent and skill files. No production code changes; CityCore, the save format and the simulation are untouched.
- **Build tooling**: none added. The skill reuses `xcodegen`, `xcodebuild` and `xcrun simctl`, as the `verify` skill does.
- **Determinism**: none; the simulation is unchanged.
