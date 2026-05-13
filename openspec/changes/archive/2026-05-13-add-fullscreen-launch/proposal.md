## Why

The MVP launches windowed on Mac and respects iPadOS multitasking (Split View, Slide Over, Stage Manager) on iPad. For a city-builder where the player is reading dense isometric terrain and tracking carrier paths across an entire island, both defaults work against the experience. The game wants the whole screen.

This change makes the app launch fullscreen on both platforms — locked on iOS/iPadOS so the system can't tile the world into a slim sidebar, and entered programmatically on Mac at first window appear. Mac users who exit fullscreen (Cmd-Ctrl-F) have that preference remembered for the next launch so we don't keep undoing their choice.

## What Changes

- iOS / iPadOS app target: set `UIRequiresFullScreen = true` in the bundled `Info.plist` (and as a property in `project.yml`'s entitlements / info block on `CitybuilderiOS`). The system stops offering Split View, Slide Over, and Stage Manager for this app. Existing landscape + portrait orientation declarations stay unchanged. (`platform-shells` modified.)
- macOS app: at first window-appear, the app SHALL programmatically enter fullscreen via `NSWindow.toggleFullScreen(nil)` unless a remembered preference flag (`Citybuilder.macLaunchFullscreen: Bool` in `UserDefaults`, default `true`) is `false`. (`platform-shells` modified.)
- macOS app: when the user manually exits fullscreen (Cmd-Ctrl-F, green-button click, View → Exit Full Screen), the app SHALL write the preference flag to `false`. When the user re-enters fullscreen, the flag flips back to `true`. The flag is observed via `NSWindow.willEnterFullScreenNotification` / `NSWindow.willExitFullScreenNotification`.
- macOS app: the existing window's `minWidth` / `minHeight` declarations (900 × 600) stay as the windowed-mode floor so an exiting-fullscreen window doesn't appear tiny. The fullscreen path bypasses those constraints by definition.
- No iOS-side preference flag. iPad multitasking is permanently disabled; if a future change wants to re-enable it (e.g. Stage Manager support for a future co-op mode), that's its own scope.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `platform-shells`: adds a fullscreen-on-launch requirement covering both platforms, plus the Mac remembered-preference behavior. The existing "Universal Apple platform support", "Adaptive HUD per idiom", and "Window management on Mac" requirements are untouched.

## Impact

- **CitybuilderiOS Info.plist** — one new key: `UIRequiresFullScreen = true`. Generated through `project.yml`. iPad users lose Split View / Slide Over / Stage Manager for this app. iPhone is unaffected (always fullscreen).
- **CitybuilderMacApp.swift** — one new small piece of logic: a SwiftUI `.onAppear` hook on the WindowGroup root that runs at most once per launch, reads `UserDefaults.standard.bool(forKey: "Citybuilder.macLaunchFullscreen")` (defaulting to true when unset), and calls `NSApplication.shared.windows.first?.toggleFullScreen(nil)` if the flag is true and the window isn't already fullscreen. Two `NotificationCenter` observers persist the flag on willEnter / willExit.
- **CityUI** — no changes. The window-management code is app-shell-side, not in the shared SwiftUI library.
- **No save-format change.** The Mac fullscreen flag is a UI preference in UserDefaults, not in the world save.
- **No new third-party dependencies.** AppKit is already linked.
- **Accessibility** — users who prefer windowed Mac play exit once and never see the prompt again. iPad users who relied on Split View lose that capability; the trade is documented in the design doc.
- **iCloud sync** — the macLaunchFullscreen preference is intentionally local. Mac and iPad have different fullscreen semantics; syncing would be confusing.
- **Out of scope, intentionally deferred**:
  - Per-monitor fullscreen targeting on Mac (move-to-display picker).
  - iPad Stage Manager support — a future change can lift `UIRequiresFullScreen` when there's a real reason.
  - "Windowed by default with a Settings toggle" — the remembered-preference behavior covers this organically.
