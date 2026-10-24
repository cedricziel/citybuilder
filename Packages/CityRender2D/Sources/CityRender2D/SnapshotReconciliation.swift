import CityCore
import Foundation

/// Per-tile drawing instruction the renderer translates into SpriteKit
/// updates. Tile and overlay sprites both flow through this type so the
/// scene layer just diffs sprite-id sets.
public struct SpriteSpec: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// A terrain tile, with the corner-mask transition its neighbours call for (nil when its
        /// corners agree). The renderer uses the transition sprite when the atlas has it.
        case terrain(TerrainType, transition: TerrainTransition? = nil, object: TerrainObject? = nil)
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
            // Houses draw a different sprite per tier; part of the key
            // so a tier change swaps the node.
            houseTier: HouseTier = .peasants,
            // Signature state: idle, monument progress, smoke tint.
            look: BuildingLook = .standard,
            // How an operational road joins its neighbours; part of the key so a new
            // neighbour swaps the node. Nil for everything else.
            roadLink: RoadLink? = nil
        )
    }

    public let coord: TileCoordinate
    public let kind: Kind

    public init(coord: TileCoordinate, kind: Kind) {
        self.coord = coord
        self.kind = kind
    }
}

/// The sprite specs a snapshot calls for. The scene asks for single tiles and for the buildings
/// (`terrainSprite`, `buildingSprites`); `desiredSprites` builds a whole range at once. Per spec
/// rendering-2_5d "Snapshot-driven rendering".
public enum SnapshotReconciler {
    /// Build the desired sprite set for one snapshot inside the visible
    /// range. Pure function.
    /// `transitions` and `roadLinks` are the scene's caches for this snapshot; without them each visible
    /// tile's transition, and every road's link, is worked out on the spot.
    public static func desiredSprites(
        in snapshot: WorldSnapshot,
        xRange: ClosedRange<Int>,
        yRange: ClosedRange<Int>,
        transitions: TerrainTransitionMap? = nil,
        roadLinks: [TileCoordinate: RoadLink]? = nil,
        objects: TerrainObjectMap? = nil,
        onScreen: CGRect? = nil
    ) -> Set<SpriteSpec> {
        var result = Set<SpriteSpec>()
        result.reserveCapacity((xRange.count) * (yRange.count) * 2)
        for tileY in yRange {
            for tileX in xRange {
                let coord = TileCoordinate(x: tileX, y: tileY)
                guard onScreen.map({ $0.contains(IsoMath.screenPoint(forTile: coord)) }) ?? true,
                      let spec = terrainSprite(at: coord, in: snapshot, transitions: transitions, objects: objects)
                else { continue }
                result.insert(spec)
            }
        }
        result.formUnion(buildingSprites(in: snapshot, xRange: xRange, yRange: yRange, roadLinks: roadLinks))
        return result
    }

    /// The terrain sprite for one tile, nil off the map. Without `transitions` the tile's transition
    /// is worked out on the spot.
    static func terrainSprite(
        at coord: TileCoordinate,
        in snapshot: WorldSnapshot,
        transitions: TerrainTransitionMap?,
        objects: TerrainObjectMap?
    ) -> SpriteSpec? {
        guard let terrainHere = snapshot.terrain(at: coord) else { return nil }
        let transition = transitions.map { $0.transition(at: coord) }
            ?? TerrainCorners.transition(at: coord, terrain: snapshot.terrain(at:))
        return SpriteSpec(coord: coord, kind: .terrain(terrainHere, transition: transition, object: objects?.object(at: coord)))
    }

    /// One sprite per building whose anchor lies in the range. Multi-tile buildings draw as a single
    /// visual unit so the "four pillars" artefact goes away.
    static func buildingSprites(
        in snapshot: WorldSnapshot,
        xRange: ClosedRange<Int>,
        yRange: ClosedRange<Int>,
        roadLinks: [TileCoordinate: RoadLink]?
    ) -> Set<SpriteSpec> {
        let roadLinks = roadLinks ?? RoadLinks.links(in: snapshot)
        var result = Set<SpriteSpec>()
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
                    houseTier: snapshot.housePopulations[building.id]?.tier ?? .peasants,
                    look: SignatureLooks.look(for: building, in: snapshot),
                    roadLink: building.kind == .road && building.state == .operational ? roadLinks[building.anchor] : nil
                )
            ))
        }
        return result
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
}
