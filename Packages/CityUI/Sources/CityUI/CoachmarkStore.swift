import Foundation

/// A place to keep one-bit flags. `UserDefaults` in the app, a dictionary
/// in tests.
public protocol FlagStoring: AnyObject {
    func flag(forKey key: String) -> Bool
    func setFlag(_ value: Bool, forKey key: String)
}

extension UserDefaults: FlagStoring {
    public func flag(forKey key: String) -> Bool {
        bool(forKey: key)
    }

    public func setFlag(_ value: Bool, forKey key: String) {
        set(value, forKey: key)
    }
}

/// Remembers which first-run hints the player has dismissed. Spec:
/// `rendering-2_5d` / First-run coach mark for touch placement.
public struct CoachmarkStore {
    public static let touchPlacementKey = "com.cedricziel.citybuilder.coachmark.touchPlacement"

    private let flags: any FlagStoring

    public init(flags: any FlagStoring = UserDefaults.standard) {
        self.flags = flags
    }

    public var shouldShowTouchPlacementHint: Bool {
        !flags.flag(forKey: Self.touchPlacementKey)
    }

    public func dismissTouchPlacementHint() {
        flags.setFlag(true, forKey: Self.touchPlacementKey)
    }
}
