import CityCore
import Foundation

/// Per-tile drawing instruction the renderer translates into SpriteKit
/// updates. Tile and overlay sprites both flow through this type so the
/// scene layer just diffs sprite-id sets.
public struct SpriteSpec: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case terrain(TerrainType)
        /// One sprite per building, anchored at the building's anchor tile.
        /// The renderer is responsible for drawing the building large
        /// enough to cover its footprint.
        ///
        /// `constructionFrameIndex` is the scaffold-stage index when the
        /// building is in `.constructing` state (nil otherwise). It is
        /// part of the spec key so the diff-based reconciler naturally
        /// replaces the node when the scaffold advances to the next
        /// stage. Frames change only a handful of times per building,
        /// so this is cheap.
        case building(
            kind: BuildingKind,
            state: BuildingState,
            footprint: Footprint,
            constructionFrameIndex: Int?,
            // Cardinal orientation for shore buildings (port, shipyard);
            // nil for non-shore buildings. The renderer uses it to pick
            // the `building-<kind>-<orientation>-*` sprite variant.
            orientation: ShoreOrientation?,
            // True when the building is `.constructing` +
            // `.waitingForMaterials`. Encoded in the spec key so the
            // diff-based reconciler swaps the node — and its
            // `overlay-waiting-materials` child — the moment the
            // substate flips.
            isWaitingForMaterials: Bool,
            // True when no road touches the footprint; drives the
            // `overlay-no-road` marker.
            isRoadDisconnected: Bool = false
        )
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
            }
        }
        // Emit one sprite per building (at its anchor) when its anchor is
        // inside the visible range. Multi-tile buildings draw as a single
        // visual unit so the "four pillars" artefact goes away.
        for building in snapshot.buildings.values where xRange.contains(building.anchor.x) && yRange.contains(building.anchor.y) {
            let spec = BuildingCatalog.spec(for: building.kind)
            let frameIndex: Int? = constructionFrameIndex(for: building, spec: spec)
            // Shore buildings (port, shipyard) carry landFace/seaFace tile
            // lists from placement; derive a cardinal orientation so the
            // renderer can pick the right `-n/-e/-s/-w` sprite variant.
            // Non-shore buildings leave both lists empty → nil orientation.
            let orientation: ShoreOrientation? = building.landFaceTiles.isEmpty
                ? nil
                : ShoreOrientationMath.orientation(
                    landFaceTiles: building.landFaceTiles,
                    seaFaceTiles: building.seaFaceTiles
                )
            let isWaiting = building.state == .constructing
                && building.constructionState == .waitingForMaterials
            result.insert(SpriteSpec(
                coord: building.anchor,
                kind: .building(
                    kind: building.kind,
                    state: building.state,
                    footprint: spec.footprint,
                    constructionFrameIndex: frameIndex,
                    orientation: orientation,
                    isWaitingForMaterials: isWaiting,
                    isRoadDisconnected: snapshot.roadDisconnectedBuildings.contains(building.id)
                )
            ))
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

    /// Scaffold-stage index for a constructing building, or nil for any
    /// other state. Factored out of `desiredSprites` so the formatting
    /// stays clean and the helper is unit-testable in isolation.
    private static func constructionFrameIndex(
        for building: Building,
        spec: BuildingSpec
    ) -> Int? {
        guard building.state == .constructing,
              let entry = SpriteAnimation.entry(for: .buildingConstructing(building.kind))
        else { return nil }
        return constructionFrame(
            ticksSincePlacement: building.ticksSincePlacement,
            duration: spec.buildDurationTicks,
            frameCount: entry.frameCount
        )
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
