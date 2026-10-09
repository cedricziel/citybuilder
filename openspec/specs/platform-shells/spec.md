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
The HUD SHALL adapt its layout to the shape of the screen on iPhone, iPad and Mac. When the view is wider than tall, the build controls MUST sit in a rail on the left edge; otherwise they MUST sit in a dock along the bottom edge. A status pill SHALL sit at the top center and the menu buttons (Goals, Research, Standings, Routes, Settings) at the top right; on a phone in portrait the menu buttons MUST fold into a single More menu. The HUD SHALL keep an 8 point margin inside the safe area on a phone and 16 points elsewhere. On a phone the rail SHALL hide its labels, the speed control SHALL be a single button and the status pill SHALL leave out the date. Layouts MUST share underlying SwiftUI views from `CityUI` and differ only in placement and chrome.

#### Scenario: iPad sidebar HUD
- **WHEN** the HUD lays out in a landscape view 1180 points wide and 820 points tall
- **THEN** the build controls are placed in the left rail with all three categories visible

#### Scenario: iPhone compact HUD
- **WHEN** the HUD lays out in a portrait view 390 points wide and 844 points tall
- **THEN** the build controls are placed in the bottom dock with the categories' drawers closed

#### Scenario: Phone portrait folds the menus
- **WHEN** the HUD layout is made for a phone in a portrait view and for a phone in a landscape view
- **THEN** the portrait layout folds the menu buttons into a More menu and the landscape layout does not

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

### Requirement: Rival market in the inspector

The inspector on a rival port SHALL show a Market section with "Sells" rows reading "<good> — $<sell price> — <quantity> available" and "Buys" rows reading "<good> — $<buy price> — wants <quantity>". An empty list SHALL read "Nothing for sale" or "Buying nothing".

#### Scenario: Market rows

- **WHEN** the player inspects a rival port whose island holds 42 wood and no tools
- **THEN** the Sells list has the row "Wood — $5 — 12 available" and the Buys list has the row "Tools — $22 — wants 20"

### Requirement: Buy and Sell in the manifest editor

For a rival port, the manifest editor SHALL label load actions "Buy" and unload actions "Sell", and each good row SHALL show the current price and offer quantity, or "no offer" when the rival has none for that good. Rival ports SHALL be selectable during route authoring like player ports.

#### Scenario: Buy label and price

- **WHEN** the player edits the manifest of a rival port that sells 12 wood
- **THEN** the load action reads "Buy" and the wood row shows "$5" and "12"

#### Scenario: Tapping a rival port

- **WHEN** the player taps a rival port while authoring a route
- **THEN** the port is appended to the in-progress waypoints

### Requirement: Routes button and route list

The HUD SHALL show a Routes button when the player owns a port or a ship, or the world has a route. It SHALL open a route list with one row per route in ID order. A row's title SHALL read "Route <n>" by list position, its stops line SHALL join the route's port stops with " → " (a player port reads "Your port (<x>, <y>)" from its anchor, a rival port "<rival name>'s port"), and its status SHALL read "Active", "Paused" or "Broken" followed by " · <n> ship" or " · <n> ships". Each row SHALL offer Pause or Resume, Assign ship and Delete, and tapping a row SHALL select it for the map overlay (tapping the selected row clears the selection). The list SHALL offer New Route.

#### Scenario: Routes button needs a port, ship or route

- **WHEN** the player owns a port
- **THEN** the Routes button is shown
- **WHEN** the player owns no port and no ship and the world has no route
- **THEN** the Routes button is hidden

#### Scenario: Route list row text

- **WHEN** the world has one active route from the player's port anchored at (3, 4) to rival Mosshold's port, with one ship assigned
- **THEN** the row reads "Route 1", "Your port (3, 4) → Mosshold's port" and "Active · 1 ship"

#### Scenario: Pausing from the route list

- **WHEN** the player taps Pause on an active route's row
- **THEN** a `setRoutePaused(id:paused: true)` command is enqueued

### Requirement: Assigning a ship to a route

The route list SHALL show the number of the player's idle ships (state `.idle`, no route). Assign ship on a row SHALL enqueue `assignShipToRoute` for the lowest-ID idle player ship. With no idle ship the button SHALL be disabled and read "No idle ship".

#### Scenario: Assign the first idle ship

- **WHEN** the player has idle ships 40 and 41 and taps Assign ship on route `R`
- **THEN** `assignShipToRoute(shipID: 40, routeID: R)` is enqueued

#### Scenario: No idle ship to assign

- **WHEN** the player's only ship is sailing a route
- **THEN** the idle ship count is 0 and Assign ship is disabled

### Requirement: Route mode

The player SHALL enter route mode from New Route in the route list, or from Route from here on any port's inspector, which adds that port as the first stop. Entering SHALL clear a pending placement, the tile menu and the route selection and SHALL reset the tool to inspect. While route mode is on, a world tap SHALL go to the route-authoring view-model (ports of any owner and water tiles add stops, land is rejected) and SHALL NOT select a tile or enqueue a command, a long-press SHALL do nothing, and the build palette and inspector SHALL be hidden. A bottom overlay SHALL list the stops and offer Undo (remove the last stop), Cancel and Commit. Its message SHALL read "Tap ports and water to add stops.", "Ships can't stop on land." after a rejected land tap, "A route needs at least two ports." after a commit with fewer than two ports, and "A red leg crosses land. Add water stops around it." after a commit with a red segment. A successful commit SHALL enqueue `CreateRoute` and leave route mode; a rejected commit SHALL stay in route mode.

#### Scenario: World taps add stops in route mode

- **WHEN** route mode is on and the player taps a water tile
- **THEN** the in-progress route gains a sea waypoint, the selected tile is unchanged and no command is enqueued

#### Scenario: Route from here starts at the port

- **WHEN** the player inspects a rival port and taps Route from here
- **THEN** route mode is on and its first stop is that port

#### Scenario: Long-press does nothing in route mode

- **WHEN** route mode is on and the player long-presses a tile
- **THEN** no tile menu is requested

#### Scenario: Commit message for a lone port

- **WHEN** the player commits a route with one port stop
- **THEN** the overlay reads "A route needs at least two ports." and route mode stays on

#### Scenario: Land tap message

- **WHEN** the player taps a land tile in route mode
- **THEN** the overlay reads "Ships can't stop on land." until the next accepted tap

#### Scenario: Undo removes the last stop

- **WHEN** the player has stops port A, sea, port B with a manifest for B and taps Undo
- **THEN** the stops are port A and sea, and B's manifest is gone

#### Scenario: Commit leaves route mode

- **WHEN** the player commits a route between two ports over open water
- **THEN** a `CreateRoute` command is enqueued and route mode is off

### Requirement: Manifest editor sheet

Each port stop in the route-mode overlay SHALL open a manifest editor for that port. The editor SHALL list the port's actions in order and SHALL add an action from a verb, a good and a quantity from 5 to 100 in steps of 5 (default 20), and remove any action. At a player port an action SHALL read "Load <qty> <good>" or "Unload <qty> <good>"; at a rival port "Buy <qty> <good> — $<sell price>" or "Sell <qty> <good> — $<buy price>". At a rival port each good choice SHALL read "<good> — $<price> — <offer>" or "<good> — no offer". Done SHALL store the actions as the port's manifest (an empty list clears it); Cancel SHALL discard the edits.

#### Scenario: Draft adds and removes actions

- **WHEN** the player adds "load 20 planks" and "unload 10 wood" and removes the first
- **THEN** the draft holds only `unloadUpTo(wood, 10)`

#### Scenario: Rival port actions read buy and sell

- **WHEN** the player edits the manifest of a rival port that sells 12 wood, holding "load up to 20 wood"
- **THEN** the action reads "Buy 20 Wood — $5" and the wood choice for Buy reads "Wood — $5 — 12"

#### Scenario: Saved manifest rides on the route

- **WHEN** the player saves "unload 10 planks" for port B and commits a route from port A to port B
- **THEN** the `CreateRoute` command's manifest for B is `[unloadUpTo(planks, 10)]`

### Requirement: Status pill and stocks tray

The status pill SHALL show the date, money, population, the current island's name and the speed control. Tapping the island name SHALL open the island's stocks tray under the pill, and tapping it again SHALL close it. The tray MUST be closed when a session starts, and MUST stay empty on a rival's island.

#### Scenario: Island name toggles the stocks tray
- **WHEN** the camera is on an island holding 12 wood and the player taps the island name
- **THEN** the stocks tray lists wood 12
- **WHEN** the player taps the island name again
- **THEN** the stocks tray is empty

### Requirement: Game speed

The speed control SHALL offer 1×, 2× and 3× game speed next to the pause button. At speed n each firing of the session's 10 Hz timer MUST advance the world by n ticks. On the compact idiom a single button SHALL step through 1×, 2× and 3× and back to 1×. Choosing a speed, or stepping it, SHALL also resume a paused game. Speed is session state and MUST NOT be saved.

#### Scenario: Double speed runs two ticks per timer firing
- **WHEN** the speed is 2× and the session's timer fires once
- **THEN** the world's tick count rises by 2

#### Scenario: Compact speed button cycles
- **WHEN** the compact speed button is tapped three times starting from 1×
- **THEN** the speed reads 2×, then 3×, then 1×

#### Scenario: Choosing a speed resumes
- **WHEN** the game is paused and the player chooses 3×
- **THEN** the speed is 3× and the game is no longer paused

### Requirement: Build categories, rail and drawers

The build controls SHALL offer three categories, Town, Gather and Craft, followed by Road and Demolish. Every player-buildable kind except the road MUST belong to exactly one category. Tapping a category SHALL open its drawer, which lists the category's visible kinds with their sprite, name, cost and lock state; tapping the open category again SHALL close it. Picking a kind in the drawer SHALL arm that tool and close the drawer. A locked kind MUST be shown dimmed with a lock and MUST NOT arm. Arming any build or demolish tool SHALL clear the selection. Opening a sheet SHALL close the drawer. With no drawer open, the category of the armed kind SHALL be highlighted. On the Mac the keys 1, 2 and 3 SHALL open the Town, Gather and Craft drawers, R SHALL arm the road and X SHALL arm demolish.

#### Scenario: Kinds sort into categories
- **WHEN** the category of the house, the lumberjack hut, the sawmill and the road is queried
- **THEN** they are Town, Gather, Craft and none

#### Scenario: Every buildable kind has one category
- **WHEN** the categories of every palette kind other than the road are queried
- **THEN** each kind has a category, and the three drawers together list each kind once

#### Scenario: Picking a drawer tile arms and closes
- **WHEN** the player opens the Craft drawer and picks the sawmill
- **THEN** the sawmill tool is armed, no drawer is open, and Craft is highlighted

#### Scenario: Locked drawer tile does nothing
- **WHEN** the player opens the Gather drawer and picks the mine before Mining is researched
- **THEN** no tool is armed and the Gather drawer stays open

#### Scenario: Arming clears the selection
- **WHEN** a building is selected and the player arms the road
- **THEN** nothing is selected

#### Scenario: Rail hotkeys
- **WHEN** the rail's hotkeys are queried
- **THEN** Town is 1, Gather is 2, Craft is 3, Road is R and Demolish is X

### Requirement: Tool strip

While a build or demolish tool is armed, the HUD SHALL show a tool strip with the tool's name, its cost, a one-line hint naming the building, the material chips for the island under the camera when no tile is hovered, and a cancel button that returns to inspect. The placement rejection banner SHALL sit directly above the tool strip. The hint SHALL read "Tap or drag to place <building>" on touch devices and "Click or drag to place <building>" on the Mac, with the building's name in lower case, and for demolish "Tap a building to demolish" or "Click a building to demolish".

#### Scenario: Tool strip chips without hover
- **WHEN** the sawmill tool is armed, no tile is hovered, and the camera is on the starting island
- **THEN** the armed cost breakdown lists 4 wood with 6 on hand and 1 plank with 5 on hand

#### Scenario: Tool strip hint
- **WHEN** the tool strip hint is built for the house on a touch device and for demolish on the Mac
- **THEN** it reads "Tap or drag to place house" and "Click a building to demolish"

### Requirement: Inspector callout

Selecting a building SHALL show the inspector as a callout next to it: 14 points right of the building's edge when the build controls are in the rail, 12 points below it when they are in the dock. When that side has no room the callout MUST flip to the other side, and it MUST stay inside the area the status pill, menus, rail and dock leave free. The callout SHALL show the building's name with a house's tier beside it, a residents meter for a house, and its key lines: residents and needs for a house, otherwise state and road. Details SHALL show every other inspector line and control, and stays open for the session once chosen. The callout SHALL offer Demolish for the player's buildings, which enqueues a demolish command for the selected tile and clears the selection.

#### Scenario: Callout title and key lines
- **WHEN** the player selects a peasant house with 2 of 4 residents
- **THEN** the inspector title is "House", its tier is "Peasants", its residents fill is one half, and its key lines start with "Residents: 2/4" followed by a "Needs:" line

#### Scenario: Callout key lines for other buildings
- **WHEN** the player selects a lumberjack hut
- **THEN** its key lines are its "State:" and "Road:" lines

#### Scenario: Callout flips at the edge
- **WHEN** a 220 by 120 point callout is placed for a building 14 points from the right edge of an 844 by 390 point view in the rail layout
- **THEN** the callout sits left of the building

#### Scenario: Callout stays on screen
- **WHEN** a 220 by 120 point callout is placed for a building at the top of the free area in the rail layout
- **THEN** the callout's top edge sits on the free area's top edge

#### Scenario: Demolish from the callout
- **WHEN** the player selects their house and taps Demolish in the callout
- **THEN** a demolish command for the house's tile is enqueued and nothing is selected
