import CoreGraphics
import Foundation

/// Where the build controls sit. Spec: `platform-shells` / Adaptive HUD
/// per idiom.
public enum HUDDock: Equatable, Sendable {
    case leftRail
    case bottomDock

    public static func placement(for size: CGSize) -> HUDDock {
        size.width > size.height ? .leftRail : .bottomDock
    }
}

/// The HUD's idiom rules in one value. Spec: `platform-shells` / Adaptive
/// HUD per idiom.
public struct HUDLayout: Equatable, Sendable {
    public let placement: HUDDock
    public let isPhone: Bool
    public let isTouch: Bool

    public static func make(size: CGSize, isPhone: Bool, isTouch: Bool) -> HUDLayout {
        HUDLayout(placement: HUDDock.placement(for: size), isPhone: isPhone, isTouch: isTouch)
    }

    public var showsDate: Bool {
        !isPhone
    }

    public var usesSpeedCycleButton: Bool {
        isPhone
    }

    /// The vertical rail drops its labels on a phone; the dock keeps them.
    public var railShowsLabels: Bool {
        !isPhone
    }

    public var foldsMenus: Bool {
        isPhone && placement == .bottomDock
    }

    public var margin: CGFloat {
        isPhone ? 8 : 16
    }

    public var railWidth: CGFloat {
        isPhone ? 56 : 76
    }

    public var controlHeight: CGFloat {
        isTouch ? 50 : 40
    }

    public var drawerColumns: Int {
        isPhone || placement == .bottomDock ? 4 : 3
    }
}
