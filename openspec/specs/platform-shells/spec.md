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
