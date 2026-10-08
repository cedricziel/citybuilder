import CityCore
import Foundation

/// How a building's sprite follows its signature state. Part of the
/// building's `SpriteSpec`, so a change swaps the node. Spec:
/// `rendering-2_5d` / Signature sprites follow their state.
public struct BuildingLook: Hashable, Sendable {
    /// Show the idle sprite instead of the operational animation: a cold
    /// engine or power plant, a gallery without a commission.
    public var idle: Bool
    /// Construction frame an operational, unfinished monument shows.
    public var projectFrame: Int?
    /// Grey tint of a smoky house.
    public var smoky: Bool

    public init(idle: Bool = false, projectFrame: Int? = nil, smoky: Bool = false) {
        self.idle = idle
        self.projectFrame = projectFrame
        self.smoky = smoky
    }

    public static let standard = BuildingLook()
}

/// A signature building's range drawn on the map.
public struct SignatureRing: Hashable, Sendable {
    public let tiles: Int
    /// Tiles within `tiles` of the footprint.
    public let bounds: TileBoundingBox
}

public enum SignatureLooks {
    /// Construction frame for a monument at `stages` (design D9).
    public static func projectFrame(stages: UInt8) -> Int {
        Int(stages) * 3 / Int(World.monumentStages)
    }

    static func look(for building: Building, in snapshot: WorldSnapshot) -> BuildingLook {
        guard building.state == .operational else { return .standard }
        var look = BuildingLook()
        if building.kind == .monument, !building.isCompletedMonument {
            look.projectFrame = projectFrame(stages: building.projectStages)
        }
        look.idle = !building.kind.signatureReaches.isEmpty && !building.isSignatureActive
        look.smoky = snapshot.houseModifiers[building.id]?.smoky ?? false
        return look
    }

    /// One ring per distinct reach of `kind`, widest first.
    public static func rings(for kind: BuildingKind, at anchor: TileCoordinate) -> [SignatureRing] {
        let footprint = Building(id: EntityID(raw: .max), kind: kind, anchor: anchor).bounds
        return Set(kind.signatureReaches.map(\.tiles)).sorted(by: >).map { tiles in
            SignatureRing(tiles: tiles, bounds: footprint.expanded(by: tiles))
        }
    }

    /// Operational buildings a `kind` source at `anchor` would affect,
    /// sorted by ID.
    public static func affectedBuildings(
        kind: BuildingKind,
        anchor: TileCoordinate,
        in snapshot: WorldSnapshot
    ) -> [EntityID] {
        let placed = snapshot.occupiedTiles[anchor].flatMap { snapshot.buildings[$0] }
        let source = placed.flatMap { $0.kind == kind && $0.anchor == anchor ? $0 : nil }
            ?? Building(id: EntityID(raw: .max), kind: kind, anchor: anchor)
        return Set(World.signatureTargets(of: source, among: snapshot.buildings.values).map(\.target.id))
            .sorted { $0.raw < $1.raw }
    }
}
