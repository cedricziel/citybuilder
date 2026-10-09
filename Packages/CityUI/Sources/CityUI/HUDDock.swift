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
