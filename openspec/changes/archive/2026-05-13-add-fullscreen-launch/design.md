## Context

The Mac app launches into a `WindowGroup` whose root is `CityRootView(session:)` (sized to a minimum of 900×600 by `.frame(minWidth:minHeight:)`). The iOS app launches into the same view in a system-managed window that respects iPadOS multitasking. Neither shell takes any action to enter fullscreen.

The convention for city-builders / strategy games is to fill the screen. Anno 1602/1404, Tropico, Banished all launch fullscreen on macOS (or at least default to it). On iPad, the modern strategy-game baseline is "no Stage Manager / Split View / Slide Over" because the iso-projected world is hard to read in a sub-half-width slice.

Two implementation surfaces:

1. **iOS / iPadOS**: a single Info.plist key, `UIRequiresFullScreen = true`, opts out of all multitasking modes. Trivial, no runtime code.
2. **macOS**: programmatic fullscreen via `NSWindow.toggleFullScreen(nil)` on first window appear. Needs a small preference flag so a user who exits fullscreen doesn't get force-re-entered on next launch.

Neither surface needs CityCore changes; this is entirely app-shell work.

## Goals / Non-Goals

**Goals:**

- iPad app launches fullscreen and stays fullscreen. No Split View, no Slide Over, no Stage Manager tile.
- Mac app launches fullscreen by default. The fullscreen entry happens once at first window appear and is invisible to the player (no flash of a small window first, if possible).
- Mac users who explicitly exit fullscreen are not re-forced into fullscreen on the next launch. The preference is remembered locally.
- iPhone behavior unchanged. iPhone apps are always fullscreen anyway; no Info.plist change is required (the key applies to iPad).

**Non-Goals:**

- Per-display targeting on Mac. The fullscreen call uses the window's current screen; the user can drag the window to another display first if they want.
- iCloud sync of the Mac fullscreen preference. Cross-device sync of a window-state setting is more confusing than useful — different displays, different keyboards, different muscle memory.
- iPad Stage Manager opt-in. The iPad ecosystem is moving toward Stage Manager but a city-builder's iso projection doesn't read well at multitasking widths. Worth revisiting once Stage Manager is the dominant iPad usage pattern.
- Borderless / cinematic "true" fullscreen on Mac (vs. the native macOS fullscreen-space approach). Native fullscreen integrates with Mission Control and Touch Bar / status menu in a way most Mac players expect.

## Decisions

### D1. iOS: Info.plist key, not runtime API

`UIRequiresFullScreen = true` is the canonical way to disable iPadOS multitasking. It's static (no runtime check needed), and the system respects it from launch. There's no `requiresFullScreen` UIWindow API on iOS that's superior.

```yaml
# project.yml — CitybuilderiOS target's info block
info:
  path: Apps/CitybuilderiOS/Info.plist
  properties:
    UIRequiresFullScreen: true
    # ... existing keys ...
```

xcodegen materializes this into the generated `Info.plist`. The project.yml change is the source of truth; the actual `Info.plist` is gitignored.

**Alternatives considered:**

- *Runtime opt-out via UIScene configuration.* Rejected — the system needs to know at app-startup time that multitasking isn't supported, before any scenes are created.
- *Per-scene fullscreen via NSUserActivity.* Doesn't apply; this is a global app-level constraint.

### D2. Mac: `.onAppear` + UserDefaults flag

The simplest reliable place to enter fullscreen is from the SwiftUI WindowGroup's root view's `.onAppear`. By the time `.onAppear` fires, the window exists; `NSApplication.shared.windows.first` is non-nil.

```swift
WindowGroup {
    CityRootView(session: session)
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            applyLaunchFullscreenIfNeeded()
        }
}

@MainActor
private func applyLaunchFullscreenIfNeeded() {
    let defaults = UserDefaults.standard
    let shouldFullscreen = defaults.object(forKey: "Citybuilder.macLaunchFullscreen") as? Bool ?? true
    guard shouldFullscreen,
          let window = NSApplication.shared.windows.first,
          !window.styleMask.contains(.fullScreen)
    else { return }
    window.toggleFullScreen(nil)
}
```

The `.onAppear` fires once per app launch (the WindowGroup creates the root view at launch and doesn't recreate it). A guard against `.fullScreen` in `styleMask` is defense-in-depth for the case where some future change pre-fullscreens the window.

To persist user intent, two notifications observe state transitions:

```swift
NotificationCenter.default.addObserver(
    forName: NSWindow.willEnterFullScreenNotification,
    object: nil, queue: .main
) { _ in
    UserDefaults.standard.set(true, forKey: "Citybuilder.macLaunchFullscreen")
}

NotificationCenter.default.addObserver(
    forName: NSWindow.willExitFullScreenNotification,
    object: nil, queue: .main
) { _ in
    UserDefaults.standard.set(false, forKey: "Citybuilder.macLaunchFullscreen")
}
```

These observers fire for every transition — programmatic or user-driven — so the flag self-heals. The launch programmatic toggle writes `true` via the willEnter handler; a user pressing Cmd-Ctrl-F writes `false` via willExit; toggling back writes `true` again.

**Alternatives considered:**

- *NSApplicationDelegate launching.* Rejected — modern SwiftUI Mac apps don't need an `NSApplicationDelegate`; the WindowGroup is the supported launch path.
- *NSWindow.styleMask.insert(.fullScreen) directly.* Rejected — that's deprecated and doesn't go through the macOS fullscreen-space transition.
- *Set the WindowGroup's initial state via SwiftUI.* SwiftUI's `WindowGroup` doesn't yet expose a `fullScreen` modifier directly; the `NSWindow` path is the supported workaround as of macOS 15.
- *Skip the remembered-preference flag.* Rejected — forcing fullscreen on every launch over a user's explicit Cmd-Ctrl-F is hostile UX.

### D3. iPhone is unaffected

iPhone apps are always fullscreen. `UIRequiresFullScreen` is an iPad-targeted key (it disables Split View etc. which iPhone doesn't support anyway). Setting it does no harm; we set it on the iOS target which covers both, and iPhone ignores it.

### D4. The flash-of-windowed problem

`NSWindow.toggleFullScreen` animates. If we enter fullscreen via `.onAppear`, the user sees a brief windowed flash before the animation. To minimize:

- The window is constructed at its minimum size (900×600), centered on the main screen — that flashes as a small centered window for ~0.2s before the fullscreen animation starts.
- A larger initial window (e.g. matching the screen size) would minimize the flash but is also wasteful.

We accept the brief flash for v0. If it bothers users in playtest, a follow-up could:
- Pre-size the window to the screen and skip the windowed render with `.hidden()` until the fullscreen transition starts.
- Use a borderless window that fills the screen instantly, bypassing the macOS fullscreen-space transition entirely.

Both have trade-offs. Native fullscreen + flash is the conventional baseline; refine if needed.

### D5. No save-format change

The Mac fullscreen preference is a single Bool in `UserDefaults.standard`. World saves are unaffected. The preference is per-machine, per-user (UserDefaults scope), not synced to iCloud. iPad has nothing to remember (always fullscreen).

## Risks / Trade-offs

- **[iPad users who relied on Side-by-Side multitasking lose it]** → Mitigation: rare for a city-builder, but if it becomes a real complaint a future change can lift the Info.plist key. We document the explicit trade in the README.
- **[Mac users coming back to a windowed game don't realize they have to manually fullscreen]** → Mitigation: the remembered-preference behavior means users who chose windowed see what they chose, and users who never exit fullscreen never have to think about it. Discoverability via View → Enter Full Screen menu item (system-provided).
- **[Programmatic fullscreen flash]** → D4 — acceptable for v0, refinable later.
- **[Edge case: window destroyed before .onAppear fires]** → Guarded by `windows.first`; harmless if it's nil (we just don't fullscreen).
- **[Edge case: user has multiple windows somehow]** → SwiftUI's WindowGroup creates one window at launch; if a future change adds a second window (e.g. an inspector palette), the launch fullscreen targets the first. Acceptable; revisit when relevant.

## Migration Plan

No data migration. The Mac fullscreen preference defaults to `true` for everyone — including existing players whose first launch with this change rolls them straight into fullscreen. If they hate it, Cmd-Ctrl-F exits and the preference sticks.

Rollback is a clean revert. No persisted state depends on the change.

## Open Questions

- **What about external display setups on Mac?** When the user has the iPad app mirrored or extended via Sidecar, fullscreen targets the active screen. Behavior is the standard macOS fullscreen-space behavior; no special handling needed.
- **iPhone landscape lock?** Out of scope — orientation declarations are existing project.yml content and this change doesn't touch them.
