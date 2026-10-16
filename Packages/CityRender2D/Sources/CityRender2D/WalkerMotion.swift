import CityCore
import SpriteKit

public extension SpriteAtlas.WalkerFacing {
    /// The facing for a step in tile space: +x is screen down-right (se),
    /// +y is down-left (sw); the larger component wins.
    init(stepX dx: Double, stepY dy: Double) {
        if abs(dx) >= abs(dy) {
            self = dx >= 0 ? .se : .nw
        } else {
            self = dy >= 0 ? .sw : .ne
        }
    }
}

extension SKNode {
    static let glideKey = "glide"

    /// Moves to the next 10 Hz position over `duration` instead of jumping,
    /// replacing any glide still running.
    func glide(to target: CGPoint, duration: TimeInterval = 0.1) {
        run(.move(to: target, duration: duration), withKey: Self.glideKey)
    }
}

extension StrollerPlanner {
    /// Residents are out walking by day and at dusk.
    static func residentsOut(atTick tick: UInt64) -> Bool {
        let phase = TimeOfDay(tick: tick).phase
        return phase == .day || phase == .dusk
    }
}
