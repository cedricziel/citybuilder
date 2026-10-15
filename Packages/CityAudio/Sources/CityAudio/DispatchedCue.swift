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
    /// The event's primary entity. A loop plays once per entity, so two
    /// workshops of one kind each get their own player.
    public let entity: EntityID?

    public init(cue: Bindings.Cue, position: TileCoordinate? = nil, entity: EntityID? = nil) {
        self.cue = cue
        self.position = position
        self.entity = entity
    }

    /// True iff this cue should be routed through the environment node.
    /// Resolves `cue.spatialize`'s tri-state: explicit `true` / `false`
    /// wins; nil defaults to spatialized only on the `.loop` bus.
    public var isSpatialized: Bool {
        if let explicit = cue.spatialize { return explicit }
        return cue.bus == .loop
    }
}
