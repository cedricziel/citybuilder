## MODIFIED Requirements

### Requirement: Universal Apple platform support
The product SHALL ship with native support for iPhone, iPad, Mac and Apple TV from a single Xcode workspace. iPhone and iPad MUST share an iOS app target with adaptive layouts; Mac MUST be a native AppKit/SwiftUI target (not Mac Catalyst); Apple TV MUST be a native tvOS target. All app targets MUST share one bundle identifier.

#### Scenario: Universal Purchase one buy
- **WHEN** a customer purchases the app on any supported platform
- **THEN** the purchase is honored on all four platforms via Universal Purchase

#### Scenario: App targets share one bundle identifier
- **WHEN** the project's app targets are listed
- **THEN** the iOS, Mac and Apple TV targets all use the bundle identifier `com.cedricziel.citybuilder`

### Requirement: Adaptive HUD per idiom
The HUD SHALL adapt its layout to the shape of the screen on iPhone, iPad, Mac and Apple TV. When the view is wider than tall, the build controls MUST sit in a rail on the left edge; otherwise they MUST sit in a dock along the bottom edge. A status pill SHALL sit at the top center and the menu buttons (Goals, Research, Standings, Routes, Settings) at the top right; on a phone in portrait the menu buttons MUST fold into a single More menu. The HUD SHALL keep an 8 point margin inside the safe area on a phone, no added margin inside the safe area on Apple TV (whose safe area already insets the screen edges), and 16 points elsewhere. On a phone the rail SHALL hide its labels, the speed control SHALL be a single button and the status pill SHALL leave out the date. On Apple TV the rail SHALL show its labels, the menu buttons MUST NOT fold, the status pill SHALL include the date, and every focusable HUD control MUST be at least 66 points tall. Layouts MUST share underlying SwiftUI views from `CityUI` and differ only in placement and chrome.

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

#### Scenario: Apple TV HUD
- **WHEN** the HUD layout is made for Apple TV in a view 1920 points wide and 1080 points tall
- **THEN** the build controls are in the left rail with labels, the menus are not folded, the status pill shows the date, the margin is 0 and the minimum control height is 66 points

### Requirement: Continuity / Handoff
On iPhone, iPad and Mac, the app SHALL support Handoff so a game opened on one device advertises itself to other signed-in devices via NSUserActivity, enabling the player to continue on another device. Apple TV does not take part in Handoff; games reach it through iCloud saves.

#### Scenario: iPad advertises game to Mac
- **WHEN** a game is open on iPad and the same Apple ID Mac is on the same network
- **THEN** the Mac shows a Handoff badge that opens the same game

### Requirement: Settings exposes audio sliders

The platform Settings surface SHALL expose a music-volume control, an SFX-volume control (each 0.0–1.0), and a master-mute toggle. On iOS and Mac every value control in Settings MUST be a slider. On Apple TV, where sliders are unavailable, every value control in Settings MUST instead be a pair of −/+ buttons that change the value by a fixed step (0.1 for the volumes), clamped to the control's range, with the current value shown (as a percentage for the volumes). The settings panel MUST also expose a "Credits & Licenses" entry that opens `CreditsView`.

#### Scenario: Settings has audio sliders

- **WHEN** the user opens Settings on any platform
- **THEN** music-volume, SFX-volume, and mute controls are visible

#### Scenario: Settings exposes credits

- **WHEN** the user opens Settings on any platform
- **THEN** a "Credits & Licenses" row is visible and tappable

#### Scenario: Stepped volume clamps at the top

- **WHEN** the music volume is 0.95 and the player activates the + button of the stepped control
- **THEN** the music volume is 1.0 and the control reads "100%"

### Requirement: Tool strip

While a build or demolish tool is armed, the HUD SHALL show a tool strip with the tool's name, its cost, a one-line hint naming the building, the material chips for the island under the camera when no tile is hovered, and a cancel button that returns to inspect. The placement rejection banner SHALL sit directly above the tool strip. The hint SHALL read "Tap or drag to place <building>" on touch devices and "Click or drag to place <building>" on the Mac, with the building's name in lower case, and for demolish "Tap a building to demolish" or "Click a building to demolish". On Apple TV the hint SHALL read "Move, then click to place <building>. Back to cancel." for a building, "Click to start painting road" or "Click to stop painting road" for the road depending on whether painting is on, and "Click a building to demolish" for demolish.

#### Scenario: Tool strip chips without hover
- **WHEN** the sawmill tool is armed, no tile is hovered, and the camera is on the starting island
- **THEN** the armed cost breakdown lists 4 wood with 6 on hand and 1 plank with 5 on hand

#### Scenario: Tool strip hint
- **WHEN** the tool strip hint is built for the house on a touch device and for demolish on the Mac
- **THEN** it reads "Tap or drag to place house" and "Click a building to demolish"

#### Scenario: Apple TV tool strip hints
- **WHEN** the tool strip hint is built on Apple TV for the house and for the road with painting off
- **THEN** it reads "Move, then click to place house. Back to cancel." and "Click to start painting road"

### Requirement: iOS audio session category

On iOS, iPadOS and tvOS, the app SHALL configure the `AVAudioSession` shared instance to category `.playback` with the `.mixWithOthers` option. This category MUST play game audio regardless of the device's Silent Mode switch (a game the user explicitly launched should not be silenced by a system-level mute) while still allowing the user's own music (Apple Music, Spotify) to continue playing alongside.

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

On iOS, iPadOS and tvOS, the audio layer SHALL observe `AVAudioSession.interruptionNotification`. On an interruption-began notification, the engine MUST pause playback on all four buses. On an interruption-ended notification with the `shouldResume` option set, the engine MUST resume playback. The simulation tick loop MUST be unaffected — interruptions affect audio only.

#### Scenario: Phone call pauses audio

- **WHEN** a phone call begins while the iOS app is in the foreground
- **THEN** the audio engine pauses within one render cycle, and the simulation tick continues advancing without interruption

#### Scenario: Phone call ends resumes audio

- **WHEN** the phone call ends and `AVAudioSession` posts an `interruptionEnded` with `shouldResume`
- **THEN** the audio engine resumes playback
