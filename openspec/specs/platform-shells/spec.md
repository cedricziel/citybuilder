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
