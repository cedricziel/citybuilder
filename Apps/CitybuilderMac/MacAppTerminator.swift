import AppKit

/// AppKit refuses to terminate while any window has a sheet attached, so
/// quitting from the pause menu (itself a sheet) silently did nothing.
/// Sheets close asynchronously, hence the deferred terminate.
enum MacAppTerminator {
    @MainActor
    static func terminate() {
        for window in NSApplication.shared.windows {
            if let sheet = window.attachedSheet {
                window.endSheet(sheet)
            }
        }
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}
