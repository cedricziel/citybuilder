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

/// The device family the HUD lays out for. Passed in rather than read
/// from the screen size, so a large Mac window never gets the TV layout.
public enum HUDIdiom: Equatable, Sendable {
    case phone
    case pad
    case mac
    case tv

    public var isTouch: Bool {
        self == .phone || self == .pad
    }
}

/// The HUD's idiom rules in one value. Spec: `platform-shells` / Adaptive
/// HUD per idiom.
public struct HUDLayout: Equatable, Sendable {
    public let placement: HUDDock
    public let idiom: HUDIdiom
    /// Narrower than 600 points, such as an iPad app in Slide Over: the
    /// minimap takes the phone's size.
    public var isCompactWidth = false

    public static func make(size: CGSize, idiom: HUDIdiom) -> HUDLayout {
        HUDLayout(placement: HUDDock.placement(for: size), idiom: idiom, isCompactWidth: size.width < 600)
    }

    public var isPhone: Bool {
        idiom == .phone
    }

    /// Hotkey letters only make sense with a keyboard.
    public var showsHotkeys: Bool {
        idiom == .mac
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

    /// Apple TV's safe area already insets the screen edges.
    public var margin: CGFloat {
        switch idiom {
        case .phone: 8
        case .tv: 0
        case .pad, .mac: 16
        }
    }

    public var railWidth: CGFloat {
        isPhone ? 56 : 76
    }

    /// The room the rail and its gap take on the left, zero with the dock.
    public var railInset: CGFloat {
        placement == .leftRail ? railWidth + 8 : 0
    }

    /// Raises a control's height to `controlHeight` on Apple TV, so every
    /// focusable control has room for its focus highlight.
    public func focusableHeight(_ height: CGFloat) -> CGFloat {
        idiom == .tv ? max(height, controlHeight) : height
    }

    /// On Apple TV the extra height leaves room for the focus highlight.
    public var controlHeight: CGFloat {
        switch idiom {
        case .phone, .pad: 50
        case .mac: 40
        case .tv: 66
        }
    }

    public var drawerColumns: Int {
        isPhone || placement == .bottomDock ? 4 : 3
    }
}
