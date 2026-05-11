import Foundation

/// An opaque identifier for an entity in the simulation. Per design D3 and
/// spec `simulation-core` ("Entity is opaque ID"), entities are integer IDs
/// rather than class instances.
public struct EntityID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UInt32

    public init(raw: UInt32) {
        self.raw = raw
    }

    public var description: String {
        "EntityID(\(raw))"
    }
}
