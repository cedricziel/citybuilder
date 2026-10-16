import CityCore
import CoreGraphics
import Foundation
import Observation

/// A building's footprint on the minimap, in its owner's colour.
public struct MinimapBuildingMarker: Equatable, Sendable {
    public let id: EntityID
    public let anchor: TileCoordinate
    public let width: Int
    public let height: Int
    public let colour: MinimapRGBA
}

/// A ship's position on the minimap, in fractional tiles.
public struct MinimapShipDot: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let colour: MinimapRGBA
}

/// A rival town as the Apple TV overview's legend names it.
public struct MinimapRival: Equatable, Sendable {
    public let name: String
    public let colourHex: String
}

/// What the minimap draws, kept between frames: the terrain image,
/// redrawn only when the terrain changes, and the building and ship
/// markers, rebuilt at most every 3 ticks. Fed one snapshot per tick by
/// `GameSession.step()`. Spec: `platform-shells` / Minimap. Design D2, D3.
@MainActor
@Observable
public final class MinimapModel {
    public private(set) var mapWidth = 0
    public private(set) var mapHeight = 0
    public private(set) var terrainImage: CGImage?
    public private(set) var buildings: [MinimapBuildingMarker] = []
    public private(set) var ships: [MinimapShipDot] = []
    public private(set) var rivals: [MinimapRival] = []
    /// The world's camera, mirrored once per frame by `GameSession` so the
    /// camera rectangle redraws when the camera moves rather than every
    /// tick.
    public internal(set) var camera = Camera()

    static let markerInterval: UInt64 = 3

    @ObservationIgnored private(set) var terrainRaster = MinimapTerrainRaster(terrain: [], mapWidth: 0, mapHeight: 0)
    @ObservationIgnored private(set) var terrainDrawCount = 0
    /// Shares the world's buffer while the terrain is unchanged, so the
    /// comparison returns at once. Design D2.
    @ObservationIgnored private var drawnTerrain: [TerrainType]?
    @ObservationIgnored private var markersTick: UInt64?
    /// The raster changed since `terrainImage` was made from it.
    @ObservationIgnored private var imageIsStale = false

    public init() {}

    /// The projection of this map onto a minimap of `size` points.
    public func projection(size: CGSize) -> MinimapProjection {
        MinimapProjection(mapWidth: mapWidth, mapHeight: mapHeight, size: size)
    }

    public func apply(_ snapshot: WorldSnapshot) {
        if let drawnTerrain, drawnTerrain != snapshot.terrainGrid {
            if mapWidth == snapshot.mapWidth, mapHeight == snapshot.mapHeight {
                terrainRaster.repaint(from: drawnTerrain, to: snapshot.terrainGrid)
                finishTerrain(snapshot)
            } else {
                drawTerrain(snapshot)
            }
        } else if drawnTerrain == nil {
            drawTerrain(snapshot)
        }
        if terrainImage == nil {
            makeImage()
        }
        if !markersAreDue(at: snapshot.tickCount) { return }
        markersTick = snapshot.tickCount
        rebuildMarkers(snapshot)
        // A terrain change shows at the markers' cadence, so a forester
        // planting every tick makes an image at most every 3 ticks.
        if imageIsStale { makeImage() }
    }

    private func makeImage() {
        terrainImage = terrainRaster.makeImage()
        imageIsStale = false
    }

    private func markersAreDue(at tick: UInt64) -> Bool {
        guard let markersTick, tick >= markersTick else { return true }
        return tick - markersTick >= Self.markerInterval
    }

    private func drawTerrain(_ snapshot: WorldSnapshot) {
        mapWidth = snapshot.mapWidth
        mapHeight = snapshot.mapHeight
        terrainRaster = MinimapTerrainRaster(
            terrain: snapshot.terrainGrid, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight
        )
        finishTerrain(snapshot)
    }

    private func finishTerrain(_ snapshot: WorldSnapshot) {
        drawnTerrain = snapshot.terrainGrid
        imageIsStale = true
        terrainDrawCount += 1
    }

    private func rebuildMarkers(_ snapshot: WorldSnapshot) {
        var colours: [Owner: MinimapRGBA] = [:]
        func colour(_ owner: Owner) -> MinimapRGBA {
            if let known = colours[owner] { return known }
            let resolved = MinimapPalette.colour(for: owner, in: snapshot)
            colours[owner] = resolved
            return resolved
        }
        let newBuildings = snapshot.buildings.values
            .sorted { $0.id.raw < $1.id.raw }
            .map { building in
                let footprint = BuildingCatalog.spec(for: building.kind).footprint
                return MinimapBuildingMarker(
                    id: building.id,
                    anchor: building.anchor,
                    width: footprint.width,
                    height: footprint.height,
                    colour: colour(building.owner)
                )
            }
        let scale = Double(Fixed.scale)
        let newShips = snapshot.ships.map { ship in
            MinimapShipDot(
                x: Double(ship.position.x.raw) / scale,
                y: Double(ship.position.y.raw) / scale,
                colour: colour(ship.owner)
            )
        }
        if newBuildings != buildings { buildings = newBuildings }
        if newShips != ships { ships = newShips }
        let newRivals = snapshot.rivals.map { MinimapRival(name: $0.name, colourHex: $0.colour.hex) }
        if newRivals != rivals { rivals = newRivals }
    }
}
