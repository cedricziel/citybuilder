import CityCore
import Foundation

/// Per-tile drawing instruction the renderer translates into SpriteKit
/// updates. Tile and overlay sprites both flow through this type so the
/// scene layer just diffs sprite-id sets.
public struct SpriteSpec: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case terrain(TerrainType)
        case occupiedMarker
    }

    public let coord: TileCoordinate
    public let kind: Kind

    public init(coord: TileCoordinate, kind: Kind) {
        self.coord = coord
        self.kind = kind
    }
}

/// Snapshot-driven scene reconciliation. Given two snapshots and a visible
/// tile range, returns three sets: sprite specs to add, to remove, and to
/// update. The scene mutates only those nodes, leaving everything else in
/// place. Per spec rendering-2_5d "Snapshot-driven rendering".
public enum SnapshotReconciler {
    /// Build the desired sprite set for one snapshot inside the visible
    /// range. Pure function.
    public static func desiredSprites(
        in snapshot: WorldSnapshot,
        xRange: ClosedRange<Int>,
        yRange: ClosedRange<Int>
    ) -> Set<SpriteSpec> {
        var result = Set<SpriteSpec>()
        result.reserveCapacity((xRange.count) * (yRange.count) * 2)
        for tileY in yRange {
            for tileX in xRange {
                let coord = TileCoordinate(x: tileX, y: tileY)
                guard let terrainHere = snapshot.terrain(at: coord) else { continue }
                result.insert(SpriteSpec(coord: coord, kind: .terrain(terrainHere)))
                if snapshot.occupiedTiles[coord] != nil {
                    result.insert(SpriteSpec(coord: coord, kind: .occupiedMarker))
                }
            }
        }
        return result
    }

    /// Difference between two desired sets: which specs to add, which to
    /// remove. Specs that exist in both sets are left in place.
    public struct Diff: Equatable, Sendable {
        public let added: Set<SpriteSpec>
        public let removed: Set<SpriteSpec>

        public init(added: Set<SpriteSpec>, removed: Set<SpriteSpec>) {
            self.added = added
            self.removed = removed
        }
    }

    public static func diff(
        previous: Set<SpriteSpec>,
        current: Set<SpriteSpec>
    ) -> Diff {
        Diff(
            added: current.subtracting(previous),
            removed: previous.subtracting(current)
        )
    }
}
