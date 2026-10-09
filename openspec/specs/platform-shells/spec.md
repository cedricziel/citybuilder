# platform-shells Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.
## Requirements
### Requirement: Universal Apple platform support
The product SHALL ship with native support for iPhone, iPad, and Mac from a single Xcode workspace. iPhone and iPad MUST share an iOS app target with adaptive layouts; Mac MUST be a native AppKit/SwiftUI target (not Mac Catalyst).

#### Scenario: Universal Purchase one buy
- **WHEN** a customer purchases the app on any supported platform
- **THEN** the purchase is honored on all three platforms via Universal Purchase

### Requirement: Adaptive HUD per idiom
The HUD SHALL adapt its layout to device idiom: compact (iPhone), regular (iPad), and Mac. Layouts MUST share underlying SwiftUI views from `CityUI` and differ only in placement and chrome.

#### Scenario: iPad sidebar HUD
- **WHEN** the app runs on iPad in landscape
- **THEN** the build palette is presented as a sidebar with full categories visible

#### Scenario: iPhone compact HUD
- **WHEN** the app runs on iPhone
- **THEN** the build palette is presented as a bottom sheet with collapsed categories

#### Scenario: Mac HUD with menu bar
- **WHEN** the app runs on Mac
- **THEN** primary actions are exposed both in the on-screen HUD and in the macOS menu bar

### Requirement: Mac keyboard hotkeys
On Mac, the system SHALL provide keyboard hotkeys for primary actions including: open build menu, select road tool, demolish tool, pause/resume, save, load, and camera controls.

#### Scenario: Pause hotkey
- **WHEN** the player presses the configured pause hotkey on Mac
- **THEN** the simulation toggles between paused and running

### Requirement: Mac hover tooltips
On Mac (and on iPad with pointer support), hovering a tile or building SHALL show a contextual tooltip with relevant information after a short delay.

#### Scenario: Hover over building shows tooltip
- **WHEN** the pointer rests on a building for the configured tooltip delay
- **THEN** a tooltip appears showing the building's name, state, and key statistics

### Requirement: Apple Pencil precision on iPad
On iPad with an Apple Pencil, the system SHALL accept pencil input for tile selection and building placement. Where supported, pencil hover SHALL preview the placement before tap.

#### Scenario: Pencil hover preview
- **WHEN** the Pencil hovers over a tile with a building selected for placement
- **THEN** a translucent preview of the building's footprint is rendered at that tile

### Requirement: Continuity / Handoff
The app SHALL support Handoff so a game opened on one device advertises itself to other signed-in devices via NSUserActivity, enabling the player to continue on another device.

#### Scenario: iPad advertises game to Mac
- **WHEN** a game is open on iPad and the same Apple ID Mac is on the same network
- **THEN** the Mac shows a Handoff badge that opens the same game

### Requirement: Window management on Mac
On Mac, the simulation SHALL run in a window that can be resized and entered/exited fullscreen. The HUD layout MUST adapt to window size.

#### Scenario: Window resize relayouts HUD
- **WHEN** the user resizes the Mac window
- **THEN** the HUD relayouts within one frame to fit the new bounds

### Requirement: iPhone "compact play" defaults
On iPhone, the default UX SHALL bias toward short sessions: larger default zoom, tap-to-inspect with bottom sheets, hidden advanced controls behind a "More" menu. Full functionality MUST remain reachable.

#### Scenario: iPhone short-session defaults
- **WHEN** the app launches on iPhone
- **THEN** the default camera zoom is higher than the iPad default and advanced controls are collapsed

### Requirement: iOS audio session category

On iOS and iPadOS, the app SHALL configure the `AVAudioSession` shared instance to category `.playback` with the `.mixWithOthers` option. This category MUST play game audio regardless of the device's Silent Mode switch (a game the user explicitly launched should not be silenced by a system-level mute) while still allowing the user's own music (Apple Music, Spotify) to continue playing alongside.

The category MUST be configured before `AVAudioEngine()` is constructed — the engine's mandatory session association at attach/connect time fails (`-10879`) when no session is configured yet, leaving the engine in a degraded state.

(Earlier drafts used `.ambient`, which respects Silent Mode and therefore left muted iPads silent — the wrong default for a game.)

#### Scenario: Player's music keeps playing

- **WHEN** the user is playing Apple Music or Spotify and launches the game on iPhone or iPad
- **THEN** their music continues uninterrupted; if the in-game music plays, both mix

#### Scenario: Audio plays even with Silent Mode enabled

- **WHEN** the iPad's Silent Mode is on and the player launches the game
- **THEN** the game's music and SFX play normally — `.playback` overrides the silent-switch behavior

#### Scenario: Session category configured before AVAudioEngine construction

- **WHEN** the iOS app constructs `AudioStack` at launch
- **THEN** `AVAudioSession.sharedInstance().category` is `.playback` before `AVAudioEngine()` is called, and the engine's first start succeeds without `-10879`

### Requirement: iOS interruption handling

On iOS and iPadOS, the audio layer SHALL observe `AVAudioSession.interruptionNotification`. On an interruption-began notification, the engine MUST pause playback on all four buses. On an interruption-ended notification with the `shouldResume` option set, the engine MUST resume playback. The simulation tick loop MUST be unaffected — interruptions affect audio only.

#### Scenario: Phone call pauses audio

- **WHEN** a phone call begins while the iOS app is in the foreground
- **THEN** the audio engine pauses within one render cycle, and the simulation tick continues advancing without interruption

#### Scenario: Phone call ends resumes audio

- **WHEN** the phone call ends and `AVAudioSession` posts an `interruptionEnded` with `shouldResume`
- **THEN** the audio engine resumes playback

### Requirement: macOS audio session no-op

On macOS, no `AVAudioSession` configuration SHALL be required or attempted. The audio engine MUST function correctly on macOS using `AVAudioEngine` alone. Interruption-handling code paths MUST be compiled out (or no-op) on macOS targets.

#### Scenario: Mac build links without AudioSession

- **WHEN** the `CitybuilderMac` target is compiled
- **THEN** no reference to `AVAudioSession` is emitted in the macOS binary

### Requirement: Settings exposes audio sliders

The platform Settings surface SHALL expose a music-volume slider, an SFX-volume slider (each 0.0–1.0), and a master-mute toggle. The settings panel MUST also expose a "Credits & Licenses" entry that opens `CreditsView`.

#### Scenario: Settings has audio sliders

- **WHEN** the user opens Settings on any platform
- **THEN** music-volume, SFX-volume, and mute controls are visible

#### Scenario: Settings exposes credits

- **WHEN** the user opens Settings on any platform
- **THEN** a "Credits & Licenses" row is visible and tappable

### Requirement: Placement rejection feedback

When a placement attempt is rejected, the HUD SHALL show a transient message that names the rejection reason in player language. The message MUST stay visible for 2.5 seconds, and a newer rejection MUST replace an older one. Shortfall messages MUST list each missing good and its quantity.

#### Scenario: Material shortfall message names the missing goods

- **WHEN** a house placement is rejected with `insufficientMaterials([.planks: 2])`
- **THEN** the HUD message reads "Needs 2 more planks"

#### Scenario: Occupied tile message

- **WHEN** a placement is rejected with `tileOccupied`
- **THEN** the HUD message reads "Tile occupied"

#### Scenario: Rejection message expires

- **WHEN** 2.5 seconds pass after a rejection message appears and no new rejection occurs
- **THEN** the HUD shows no rejection message

### Requirement: HUD good icons load from the bundled atlas

The HUD stocks row SHALL show each good's pixel-art icon, resolved from the compiled `Icons` texture atlas in the app bundle. The SF Symbol fallback MUST appear only when a good has no entry in that atlas.

#### Scenario: Bundled good icon resolves from the compiled atlas

- **WHEN** the icon loader resolves `wood` against a bundle that contains a compiled `Icons` atlas with a `good-wood` texture
- **THEN** the loader reports the atlas as its origin, not the fallback

#### Scenario: Missing good icon falls back to the symbol

- **WHEN** the icon loader resolves a good that has no texture in the `Icons` atlas
- **THEN** the loader reports the fallback origin

### Requirement: Compact HUD labels stay on one line

On the compact (iPhone) idiom, HUD stat values, stat captions, and build-palette entry labels SHALL each render on a single line, and money values MUST use locale-grouped digits (for example "$1,000"). A label that does not fit MUST shrink or truncate, never wrap.

#### Scenario: Compact money value uses grouped digits

- **WHEN** the HUD formats a balance of 1000 for the compact idiom in the `en_US` locale
- **THEN** the text is "$1,000"

#### Scenario: Compact layout limits labels to one line

- **WHEN** the compact layout's label configuration is queried
- **THEN** stat values, stat captions, and palette labels each declare a line limit of 1

### Requirement: Build palette lists only player-buildable kinds

The build palette SHALL offer every building kind the player may place, and MUST NOT offer the town center, which world generation seeds for free.

#### Scenario: Palette omits the town center

- **WHEN** the build palette's kind list is queried
- **THEN** it contains house, farm and road, and does not contain the town center

### Requirement: Terrain rejection message

A placement rejected for missing required terrain SHALL show a message naming the terrain in player language.

#### Scenario: Mountain requirement message

- **WHEN** a placement is rejected with `needsTerrain(.mountain)`
- **THEN** the HUD message reads "Needs mountain ground"

### Requirement: Research panel

The HUD SHALL offer a research button that opens a panel listing every tech with its cost, progress, prerequisites, unlocked buildings and state (researched, available, locked). Choosing an available tech MUST issue the choose-research command.

#### Scenario: Research panel lists tech states

- **WHEN** the research panel model is built for a new game
- **THEN** Scholarship is listed as researched, Metallurgy as locked, and Milling, Mining and Seafaring as available

### Requirement: Locked palette entries

Build palette entries for buildings whose tech is not researched SHALL be marked locked, and a locked placement MUST show "Needs <Tech> research".

#### Scenario: Locked placement message

- **WHEN** a placement is rejected with `locked(.mining)`
- **THEN** the HUD message reads "Needs Mining research"

### Requirement: HUD shows the date

The HUD SHALL show the current season and year, such as "Spring 1200".

#### Scenario: HUD date text

- **WHEN** the HUD applies a snapshot dated autumn 1203
- **THEN** its date text is "Autumn 1203"

### Requirement: History events show a banner

When a history event fires, the game screen SHALL show a banner with the event's title and description for 60 ticks.

#### Scenario: Banner appears and expires

- **WHEN** a tick emits a trade caravan history event
- **THEN** the session exposes a banner titled "Trade caravan" for the next 60 ticks, and none after

### Requirement: New Game offers a culture

The New Game dialog SHALL let the player pick one of the four cultures, show a one-line description of the selected culture, default to Northern European, and create the world with the selected culture.

#### Scenario: Chosen culture reaches the world

- **WHEN** the player selects Middle Eastern and starts
- **THEN** the committed world's culture is Middle Eastern

#### Scenario: Cancel resets the culture

- **WHEN** the player selects East Asian and cancels
- **THEN** the dialog's culture is Northern European again

### Requirement: Inspector uses culture tier names

The inspector SHALL name a house's tier with the world culture's name for it.

#### Scenario: Mediterranean inspector

- **WHEN** the inspector shows a peasants-tier house in a Mediterranean world
- **THEN** its tier line reads "Tier: Plebeians"

### Requirement: New Game offers a starting age

The New Game dialog SHALL let the player pick one of the five ages, default to Medieval, reset to Medieval on cancel, and create the world in the selected age.

#### Scenario: Chosen age reaches the world

- **WHEN** the player selects Industrial and starts
- **THEN** the committed world's age is Industrial

### Requirement: Age changes show a banner

When the age advances, the game screen SHALL show a banner titled "The <Age> age begins" for 60 ticks.

#### Scenario: Medieval banner

- **WHEN** a tick emits `ageAdvanced(medieval)`
- **THEN** the session's banner title is "The Medieval age begins"

### Requirement: Palette hides obsolete buildings

The build palette SHALL leave out building kinds that are obsolete in the world.

#### Scenario: Quern house leaves the palette

- **WHEN** Milling is researched
- **THEN** the palette has no quern house entry

### Requirement: New Game offers difficulty and scenarios

The New Game dialog SHALL offer a Sandbox mode with a difficulty picker (default Normal) and a Scenario mode listing the built-in scenarios; starting creates the world from the selection.

#### Scenario: Scenario reaches the world

- **WHEN** the player picks Scenario mode, selects The Guild Town and starts
- **THEN** the committed world has The Guild Town's goals and Normal difficulty

#### Scenario: Sandbox difficulty reaches the world

- **WHEN** the player picks Hard in Sandbox mode and starts
- **THEN** the committed world is Hard with no goals

### Requirement: Goals panel and win sheet

In a scenario game the HUD SHALL offer a goals panel listing each goal with its progress, and winning SHALL show a "Scenario complete" sheet.

#### Scenario: Goal progress text

- **WHEN** the goals panel shows "40 residents" with 24 residents in the city
- **THEN** the row reads "Residents 24/40"

#### Scenario: Win sheet appears

- **WHEN** a tick emits `scenarioWon`
- **THEN** the session presents the win sheet

### Requirement: Inspector introduces residents

The inspector SHALL list up to three residents of a house with their tier and the house's wish.

#### Scenario: Resident line

- **WHEN** the inspector shows a peasants house whose wish is food
- **THEN** a line reads "<name> · Peasants · wants food"

### Requirement: Palette hides other cultures' buildings

The build palette SHALL leave out buildings tied to another culture.

#### Scenario: Mediterranean palette

- **WHEN** the palette is built for a Mediterranean world
- **THEN** it has a vineyard and a winery and no brewery, tea house or roastery

### Requirement: Signature inspector

The inspector SHALL show, for a monument, its stage out of 25 or "Complete: taxes +10%"; for a guild hall, how many workshops it speeds up; for a gallery, a "Commission art ($200)" button, disabled while a commission runs or the balance is below $200, and the time left of a running commission; for a steam engine and a power plant, whether it is fuelled and how many workshops and houses it affects. A house's inspector SHALL note when it is smoky, energised or inspired.

#### Scenario: Commission button

- **WHEN** the player selects a gallery with no commission and a balance of $500, and taps "Commission art ($200)"
- **THEN** a commission command for that gallery is enqueued, and the button is disabled once the commission runs

#### Scenario: Smoky house note

- **WHEN** the player selects a smoky merchant house
- **THEN** the inspector shows "Smoky: −2 residents"

### Requirement: Signature banners

The game SHALL show a banner for `monumentCompleted` ("The monument is complete"), `fuelRanOut` ("<Kind> is out of charcoal") and `commissionEnded` ("The gallery's commission has ended").

#### Scenario: Out of charcoal banner

- **WHEN** a tick's events include `fuelRanOut` for a steam engine
- **THEN** a banner reads "Steam engine is out of charcoal"

### Requirement: Culture signature inspector

The inspector SHALL show whether a culture signature building is served and how many buildings, houses or residents it affects. For a caravanserai it SHALL show an export picker listing "None" and every good except coffee in catalog order, the time to the next caravan and what the last caravan sold.

#### Scenario: Picking an export

- **WHEN** the player selects a caravanserai and picks bread in the export picker
- **THEN** a `setExport` command for that caravanserai with bread is enqueued

#### Scenario: Last caravan line

- **WHEN** the last caravan of the selected caravanserai sold 4 bread for $48
- **THEN** the inspector shows "Last caravan: 4 bread for $48"

### Requirement: Out-of-luxury banner

The `fuelRanOut` banner SHALL name the building's fuel good: "<Kind> is out of <good>".

#### Scenario: Forum out of wine

- **WHEN** a tick's events include `fuelRanOut` for a forum
- **THEN** a banner reads "Forum is out of wine"

### Requirement: New Game offers rival towns

In Sandbox mode with the Archipelago layout, the New Game dialog SHALL show a "Rival towns" toggle, on by default, and the committed world SHALL have rivals only when it is on. Selecting the Island Rivalry scenario SHALL set the layout to Archipelago and disable the layout picker.

#### Scenario: Toggle reaches the world

- **WHEN** the player picks Archipelago and Normal, turns "Rival towns" off and starts
- **THEN** the committed world has no rivals

#### Scenario: Island Rivalry locks the layout

- **WHEN** the player picks Scenario mode with Single Island selected and then selects Island Rivalry
- **THEN** the layout is Archipelago and the layout picker is disabled

### Requirement: Standings panel

When the world has rivals, the HUD SHALL offer a standings panel listing each standing row with a colour swatch, name, population, age and wealth, with the player's row in bold. Without rivals the button SHALL be hidden.

#### Scenario: Standings row text

- **WHEN** the panel shows a rival named Ravenshore with 52 residents in the Medieval age and $1,234
- **THEN** its row reads "Ravenshore", "52", "Medieval" and "$1,234"

#### Scenario: Hidden without rivals

- **WHEN** a single-island world is shown
- **THEN** the HUD has no standings button

### Requirement: Rival islands and buildings in the UI

A `foreignIsland` rejection SHALL read "<rival name>'s island — you can't build here." The inspector on a rival building SHALL show the rival's name and colour, use the rival culture's tier names and hide Demolish. When the camera's island belongs to a rival, the island overlay SHALL show "<rival name> (rival)" and hide the stocks row. A `rivalAgeAdvanced` event SHALL show the banner "<rival name> enters the <age>".

#### Scenario: Foreign island text

- **WHEN** a placement on Ravenshore's island is rejected
- **THEN** the banner reads "Ravenshore's island — you can't build here."

#### Scenario: Rival inspector

- **WHEN** the player inspects a peasants' house of a Mediterranean rival
- **THEN** the inspector shows the rival's name, the tier name "Plebeians", and no Demolish button

#### Scenario: Rival island overlay

- **WHEN** the camera centers on Ravenshore's island
- **THEN** the island overlay reads "Ravenshore (rival)" and shows no stocks row

#### Scenario: Rival age banner

- **WHEN** a tick emits `rivalAgeAdvanced` for Ravenshore and the Renaissance
- **THEN** the session shows the banner "Ravenshore enters the Renaissance"
