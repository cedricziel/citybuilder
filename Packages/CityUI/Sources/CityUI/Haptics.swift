/// One touch of feedback, named by what happened rather than how it feels.
public enum HapticFeedback: Equatable, Sendable {
    /// A building or road went down.
    case placed
    /// A placement was turned down.
    case refused
    /// A monument or the scenario goal was completed.
    case success
    /// A seasonal event was announced.
    case warning
}

/// Where the game asks for haptics. Tests pass a recording fake; the
/// phone gets the system generators; Mac and Apple TV get nothing.
@MainActor
public protocol HapticPlaying: AnyObject {
    func play(_ feedback: HapticFeedback)
}

/// The no-op player for platforms without a haptic engine.
@MainActor
public final class SilentHaptics: HapticPlaying {
    public init() {}

    public func play(_: HapticFeedback) {}
}

#if os(iOS)
import UIKit

/// iPhone and iPad haptics through the system generators, which follow the
/// system haptics setting.
@MainActor
public final class SystemHaptics: HapticPlaying {
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()

    public init() {}

    public func play(_ feedback: HapticFeedback) {
        switch feedback {
        case .placed: impact.impactOccurred()
        case .refused, .warning: notification.notificationOccurred(.warning)
        case .success: notification.notificationOccurred(.success)
        }
    }
}

extension GameSession {
    static func platformHaptics() -> any HapticPlaying {
        SystemHaptics()
    }
}
#else
extension GameSession {
    static func platformHaptics() -> any HapticPlaying {
        SilentHaptics()
    }
}
#endif
