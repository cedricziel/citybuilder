import Foundation

/// A player- or system-issued command queued for application at the next tick
/// boundary. Per spec `simulation-core` ("Command applied at next tick") and
/// design D2.
///
/// Cases will grow over time. M1 only needs a non-empty placeholder so the
/// enum can compile and the queue can be exercised.
public enum Command: Codable, Equatable, Sendable {
    /// No-op command. Useful for testing the queue plumbing without other side
    /// effects. Removed once real commands exist for every behavior.
    case noop

    /// Mark a forest tile as harvested. Used by world-terrain to drive the
    /// "Forest tile can be cleared" scenario.
    case harvestForest(at: TileCoordinate)
}
