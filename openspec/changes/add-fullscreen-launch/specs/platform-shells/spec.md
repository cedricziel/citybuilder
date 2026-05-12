## ADDED Requirements

### Requirement: iPad fullscreen lock

On iPad, the app SHALL declare `UIRequiresFullScreen = true` in its `Info.plist`. This opts the app out of Split View, Slide Over, and Stage Manager — the system does not offer those multitasking modes for this app, and the app always presents its window at the full screen size. iPhone is unaffected (always fullscreen by platform default).

#### Scenario: iPad app launches fullscreen with no multitasking

- **WHEN** the iPad app launches and the user attempts to invoke Split View, Slide Over, or Stage Manager
- **THEN** the system does not offer the tiling affordance for this app, and the app's window continues to fill the screen

#### Scenario: iPhone unaffected by the iPad lock

- **WHEN** the iPhone app launches
- **THEN** it runs fullscreen as iPhone apps always do, and the `UIRequiresFullScreen` declaration has no observable effect

### Requirement: Mac launches fullscreen by default

On macOS, the app SHALL enter fullscreen at first window appear by calling `NSWindow.toggleFullScreen(nil)` on `NSApplication.shared.windows.first`, unless the remembered preference `Citybuilder.macLaunchFullscreen` in `UserDefaults.standard` is `false`. The preference defaults to `true` when unset.

#### Scenario: Mac launches fullscreen by default

- **WHEN** a fresh-install Mac app launches with no value stored for `Citybuilder.macLaunchFullscreen`
- **THEN** the app enters native macOS fullscreen within one render cycle of the main window appearing

#### Scenario: Mac respects an explicit windowed preference

- **WHEN** the Mac app launches and `Citybuilder.macLaunchFullscreen` is stored as `false`
- **THEN** the app launches windowed; no programmatic fullscreen call is made

### Requirement: Mac remembers user-driven fullscreen transitions

When the user enters or exits fullscreen on Mac (Cmd-Ctrl-F, green-button click, View → Enter Full Screen, or any other system-level path), the app SHALL update `Citybuilder.macLaunchFullscreen` in `UserDefaults.standard` to reflect the new state. The next launch reads this flag and matches the user's last choice.

#### Scenario: Mac remembers a manual exit-fullscreen preference

- **WHEN** the user exits fullscreen via Cmd-Ctrl-F (or any equivalent path) and relaunches the app
- **THEN** the next launch comes up windowed; the preference flag reads `false`

#### Scenario: Mac re-launches fullscreen after a user re-enters fullscreen

- **WHEN** the user (after a previous exit) re-enters fullscreen via Cmd-Ctrl-F and relaunches the app
- **THEN** the next launch enters fullscreen; the preference flag reads `true`

### Requirement: Mac windowed-mode floor

When the Mac app is in windowed mode (after a user exit-fullscreen), the window's minimum width and height SHALL remain at the existing 900 × 600 pixels so the HUD and build palette stay usable. Fullscreen bypasses these constraints by definition.

#### Scenario: Windowed Mac respects the 900x600 floor

- **WHEN** a Mac user exits fullscreen and attempts to resize the window below 900 × 600
- **THEN** the system clamps the window to the minimum, preserving HUD legibility
