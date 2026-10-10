## MODIFIED Requirements

### Requirement: Universal Apple platform support

The product SHALL ship with native support for iPhone, iPad, Mac and Apple TV from a single Xcode workspace. iPhone and iPad MUST share an iOS app target with adaptive layouts; Mac MUST be a native AppKit/SwiftUI target (not Mac Catalyst); Apple TV MUST be a native tvOS target. All app targets MUST share one bundle identifier.

#### Scenario: Universal Purchase one buy

- **WHEN** a customer purchases the app on any supported platform
- **THEN** the purchase is honored on all four platforms via Universal Purchase

#### Scenario: App targets share one bundle identifier

- **WHEN** the project's app targets are listed
- **THEN** the iOS, Mac and Apple TV targets all use the bundle identifier `com.cedricziel.citybuilder`

### Requirement: Settings exposes audio sliders

The platform Settings surface SHALL expose a music-volume control, an SFX-volume control (each 0.0–1.0), and a master-mute toggle. On iOS and Mac the volume controls MUST be sliders. On Apple TV, where sliders are unavailable, each volume control MUST be a pair of −/+ buttons that change the volume in steps of 0.1, clamped to 0.0–1.0, with the current value shown as a percentage. The settings panel MUST also expose a "Credits & Licenses" entry that opens `CreditsView`.

#### Scenario: Settings has audio sliders

- **WHEN** the user opens Settings on any platform
- **THEN** music-volume, SFX-volume, and mute controls are visible

#### Scenario: Settings exposes credits

- **WHEN** the user opens Settings on any platform
- **THEN** a "Credits & Licenses" row is visible and tappable

#### Scenario: Stepped volume clamps at the top

- **WHEN** the music volume is 0.95 and the player activates the + button of the stepped control
- **THEN** the music volume is 1.0 and the control reads "100%"

## ADDED Requirements

### Requirement: TV HUD layout

On Apple TV the HUD SHALL use a TV layout. The build controls MUST sit in the left rail with labels shown, the status pill MUST include the date, and the menu buttons MUST sit at the top right without folding into a More menu. The HUD MUST keep a margin of 60 points from the top and bottom edges and 80 points from the left and right edges, so that it stays inside the TV's safe area. Every focusable HUD control MUST be at least 66 points tall.

#### Scenario: TV layout on a 1920 × 1080 screen

- **WHEN** the HUD lays out for Apple TV in a view 1920 points wide and 1080 points tall
- **THEN** the build controls are in the left rail with labels, the menus are not folded, and the margins are 60 points vertically and 80 points horizontally

### Requirement: tvOS audio session

On Apple TV the app SHALL configure the audio session with the same category, options, ordering and interruption handling as on iOS: category `.playback` with `.mixWithOthers`, set before the audio engine is constructed, with playback paused on an interruption and resumed when the interruption ends with `shouldResume`.

#### Scenario: tvOS session configured before engine construction

- **WHEN** the Apple TV app constructs `AudioStack` at launch
- **THEN** the session category is `.playback` with `.mixWithOthers` before the audio engine is constructed

### Requirement: No Handoff on Apple TV

The Apple TV app SHALL NOT advertise games through Handoff and SHALL NOT offer to continue a game from another device through Handoff. Games still move between devices through iCloud saves.

#### Scenario: Apple TV session advertises no activity

- **WHEN** a game is open on Apple TV
- **THEN** the session publishes no Handoff user activity

### Requirement: No keyboard shortcuts on Apple TV

Controls that carry keyboard shortcuts on the Mac SHALL remain reachable on Apple TV through focus and the remote, and the Apple TV build MUST NOT depend on keyboard shortcuts.

#### Scenario: Pause reachable without a keyboard

- **WHEN** the game runs on Apple TV with no keyboard connected
- **THEN** the player can pause and resume through Play/Pause on the remote and through the pause menu
