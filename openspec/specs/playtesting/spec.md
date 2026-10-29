# playtesting Specification

## Purpose
TBD - created by archiving change add-playtest-harness. Update Purpose after archive.
## Requirements
### Requirement: Player personas

The project SHALL define seven player personas as agent files `.claude/agents/playtester-<slug>.md`, with the slugs `newcomer`, `optimizer`, `builder`, `veteran`, `trader`, `chaos` and `returning`. Each file SHALL have frontmatter with `name` (equal to the file name without the extension), a `description` that says when to use the persona, `tools`, `model: sonnet` and `effort: medium`. The tools SHALL include Bash, Read, Write and the simulator control tool. Each body SHALL give the player's background, goals, playstyle, patience, what the player notices and how the player decides to quit, SHALL tell the agent to load the `playtest` and `verify` skills and to play the real app through the simulator UI, and SHALL ask for feedback in the player's voice.

#### Scenario: Every persona has an agent file

- **WHEN** the agent files in `.claude/agents` are listed
- **THEN** a `playtester-<slug>.md` file exists for each of the seven persona slugs

#### Scenario: Persona frontmatter is complete

- **WHEN** a persona's frontmatter is read
- **THEN** it names the file's slug, has a description, uses the sonnet model at medium effort, and lists Bash, Read, Write and the simulator control tool

#### Scenario: Persona bodies cover the player

- **WHEN** a persona's body is read
- **THEN** it has sections for background, goals, playstyle, patience, what it notices and when it quits

### Requirement: Personas play the real app, within limits

A persona SHALL play only through the simulator control tool: screenshots, taps, swipes, text and the launch action. A persona SHALL NOT use computer use or desktop screen control, and SHALL NOT read the game's source code to decide how to play. A persona MAY launch with a debug flag that stages a state (a seed, a culture, an age, a season, a number of seasons, a camera, a lived town or a port) and SHALL NOT use a flag that acts for the player. A persona SHALL play for at least 30 minutes of real play, or until its quit rule fires, and SHALL take a screenshot at each key moment and quote the on-screen text when it reports a problem.

#### Scenario: Personas forbid desktop control

- **WHEN** a persona's body is read
- **THEN** it forbids computer use and desktop screen control

#### Scenario: Personas set a minimum session

- **WHEN** a persona's body is read
- **THEN** it asks for at least 30 minutes of real play or the persona's quit rule

### Requirement: Device assignment

Each persona SHALL be assigned one device and orientation, recorded in its agent file: newcomer on an iPhone in portrait, optimizer on an iPad in landscape, builder on an iPad in portrait, trader on an iPhone in landscape, veteran on the Mac, chaos on a small iPhone (iPhone SE size) and returning on a Pro Max iPhone. The report SHALL record the device and orientation.

#### Scenario: Each persona names its device

- **WHEN** a persona's body is read
- **THEN** it states the assigned device and orientation, matching the device matrix

### Requirement: One simulator at a time

A playtest session SHALL check that no simulator is booted before it boots its own, SHALL boot only the device it needs, and SHALL shut that device down at the end, whatever the outcome. A session SHALL NOT shut down or erase a device it did not boot or create.

#### Scenario: The skill states the one-simulator rule

- **WHEN** the playtest skill is read
- **THEN** it tells the session to check for booted simulators first, to boot one device, and to shut it down afterwards

### Requirement: Playtest skill

The project SHALL have a skill `.claude/skills/playtest/SKILL.md` that covers: how to build and start a session, the one-simulator rule, how to boot a given device and rotate it, how to read the screen reliably (a screenshot before and after every action), the debug launch flags a tester may and may not use, how a returning player installs an old save, the Apple TV and Mac limits, where screenshots go (`playtests/<date>-<persona>/`), and the report formats. Every `-uiTest…` flag the skill names SHALL exist in the app sources.

#### Scenario: The skill covers the session

- **WHEN** the playtest skill is read
- **THEN** it has sections for starting a session, the one-simulator rule, reading the screen, launch flags, platform limits and reports

#### Scenario: Flags in the skill exist

- **WHEN** the skill names a `-uiTest…` launch flag
- **THEN** the same flag appears in the app or package sources

### Requirement: Session report

Each persona session SHALL write one markdown report to `playtests/<date>-<persona>-<seed>.md` and its screenshots to `playtests/<date>-<persona>/`. The report SHALL contain: the setup (device, orientation, build, flags, difficulty, culture, seed), a timeline of key moments, what was fun, what was confusing or frustrating with the exact on-screen text, bugs with exact steps to repeat, balance observations with numbers, the top three changes the persona wants, a fun rating from 1 to 10 and whether the persona would keep playing. It SHALL be written in the player's voice and be ready to commit.

#### Scenario: The skill defines the report sections

- **WHEN** the playtest skill is read
- **THEN** it lists every section of the session report, the report path and the screenshot folder

### Requirement: UI auditor

The project SHALL define an eighth agent, `playtester-ui-auditor`, that is not a player persona. It SHALL review the app screen by screen: the HUD, the build rail and drawer, the inspector, the goals, research, standings, market, statistics and routes panels, hints and banners, the pause menu and settings, and save and load. It SHALL review each on iPhone SE size, iPhone standard size and Pro Max in portrait and landscape, on an 11-inch iPad in portrait and landscape, on Apple TV and on the Mac. Its checklist SHALL cover tap targets of at least 44 points, text legibility and truncation, safe areas, overlap and occlusion, Dynamic Type at large sizes, portrait and landscape reflow, dark and light appearance and contrast, VoiceOver labels, tvOS focus order and focus ring, and Mac pointer, hover, keyboard shortcuts and window resizing. It SHALL write one report per device and one cross-device matrix, and each problem SHALL carry a severity, a screenshot and the exact screen.

#### Scenario: The auditor covers the device matrix

- **WHEN** the auditor's body is read
- **THEN** it lists every device size and orientation above

#### Scenario: The auditor carries the checklist

- **WHEN** the auditor's body is read
- **THEN** it lists each checklist item and requires a severity, a screenshot and the exact screen for each problem

### Requirement: Apple TV and Mac limits

The skill SHALL state that the simulator control tool drives a tvOS simulator with arrow keys and return, and which remote buttons it cannot send. For the Mac, desktop input and computer use SHALL stay forbidden: the Mac app SHALL be reviewed from window-only captures of a process the session launched and identified by its PID, with debug launch flags to reach states, and from a read of the keyboard and pointer code. A Mac report SHALL say that Mac interaction was not exercised by hand.

#### Scenario: The skill records the platform limits

- **WHEN** the playtest skill is read
- **THEN** it explains how to drive tvOS, how to capture only a Mac window, and that Mac interaction is not exercised by hand
