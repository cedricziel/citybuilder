import Foundation

/// Persisted preference for whether the Mac shell launches into
/// fullscreen on first window appear. Wraps `UserDefaults` so the
/// app shell can call into a testable value type instead of touching
/// `UserDefaults.standard` directly. Spec: `add-fullscreen-launch` /
/// `platform-shells` Requirement: Mac launches fullscreen by default.
public struct MacLaunchFullscreenPreferences {
    /// Default-on so the very first launch enters fullscreen. The
    /// user's explicit Cmd-Ctrl-F flips it false; the willEnter/
    /// willExit notifications keep the value in sync afterwards.
    public static let defaultsKey = "Citybuilder.macLaunchFullscreen"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// True when the next launch should programmatically enter
    /// fullscreen. Defaults to `true` when nothing is stored — fresh
    /// installs and CI runs both fullscreen unless the user has
    /// previously chosen otherwise.
    public var shouldLaunchFullscreen: Bool {
        defaults.object(forKey: Self.defaultsKey) as? Bool ?? true
    }

    /// Update the stored flag. The Mac shell's notification observers
    /// call this from `willEnter`/`willExit` so the next launch
    /// matches whatever the user chose last.
    public func setShouldLaunchFullscreen(_ value: Bool) {
        defaults.set(value, forKey: Self.defaultsKey)
    }
}
