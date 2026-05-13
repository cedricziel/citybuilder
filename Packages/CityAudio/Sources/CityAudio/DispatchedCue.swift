import CityCore
import Foundation

/// A `Bindings.Cue` paired with the runtime position the coordinator
/// resolved from the event's `primaryEntityID` against the cached
/// `WorldSnapshot`. Per spec `audio-playback` design D2 — keeps
/// `Bindings.Cue` Codable and stable while letting the spatial layer
/// pick up per-instance positions.
public struct DispatchedCue: Sendable, Equatable {
    public let cue: Bindings.Cue
    public let position: TileCoordinate?

    public init(cue: Bindings.Cue, position: TileCoordinate? = nil) {
        self.cue = cue
        self.position = position
    }

    /// True iff this cue should be routed through the environment node.
    /// Resolves `cue.spatialize`'s tri-state: explicit `true` / `false`
    /// wins; nil defaults to spatialized only on the `.loop` bus.
    public var isSpatialized: Bool {
        if let explicit = cue.spatialize { return explicit }
        return cue.bus == .loop
    }
}
