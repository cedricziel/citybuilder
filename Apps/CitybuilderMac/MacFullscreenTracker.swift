import AppKit
import CityUI
import Foundation

/// AppKit-side wiring for the Mac launch-fullscreen behavior. The
/// SwiftUI WindowGroup root view calls `applyLaunchFullscreenIfNeeded`
/// from `.onAppear`; the tracker keeps `NotificationCenter`
/// observers alive so user-driven fullscreen transitions update the
/// remembered preference. Spec: `add-fullscreen-launch` /
/// `platform-shells` Requirement: Mac launches fullscreen by default
/// + Mac remembers user-driven fullscreen transitions.
final class MacFullscreenTracker {
    private let preferences: MacLaunchFullscreenPreferences
    private var observers: [NSObjectProtocol] = []

    init(preferences: MacLaunchFullscreenPreferences = MacLaunchFullscreenPreferences()) {
        self.preferences = preferences
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.willEnterFullScreenNotification,
            object: nil, queue: .main
        ) { [preferences] _ in
            preferences.setShouldLaunchFullscreen(true)
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.willExitFullScreenNotification,
            object: nil, queue: .main
        ) { [preferences] _ in
            preferences.setShouldLaunchFullscreen(false)
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Runs from the WindowGroup root view's `.onAppear`. Enters
    /// fullscreen exactly once at launch when the remembered
    /// preference is `true` and the window isn't already fullscreen.
    @MainActor
    func applyLaunchFullscreenIfNeeded() {
        guard preferences.shouldLaunchFullscreen else { return }
        guard let window = NSApplication.shared.windows.first else { return }
        guard !window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
    }
}
