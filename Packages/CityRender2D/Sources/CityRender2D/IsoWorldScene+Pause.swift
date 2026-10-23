import Foundation

/// Spec: `rendering-2_5d` / Figures stand still while the game is paused.
extension IsoWorldScene {
    /// How long without a new tick before figures stop walking.
    static let stillAfter: TimeInterval = 0.3

    /// Notes when the simulation tick last changed, so figures can stand still while the game is paused.
    func noteTick(_ tick: UInt64, now: TimeInterval) {
        if tick != tickSeen {
            tickSeen = tick
            tickSeenAt = now
        }
    }

    /// No new tick for a while: the game is paused, or the title screen shows a still town.
    func simulationIsStill(now: TimeInterval) -> Bool {
        now - tickSeenAt > Self.stillAfter
    }
}
