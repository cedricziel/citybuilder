import Foundation

/// Immutable, render-friendly slice of `World` taken once per frame. The
/// renderer consumes snapshots and MUST NOT hold a reference to `World`
/// itself (spec rendering-2_5d "Snapshot-driven rendering").
///
/// Carriers and other moving entities will gain their own collections in
/// later milestones; for M1 the snapshot exposes terrain, occupancy, the
/// tick clock, and the camera so the renderer has everything it needs.
public struct WorldSnapshot: Hashable, Sendable {
    public let tickCount: UInt64
    public let simulatedTime: SimulationDuration
    public let mapWidth: Int
    public let mapHeight: Int
    public let terrainGrid: [TerrainType]
    public let occupiedTiles: [TileCoordinate: EntityID]
    public let buildings: [EntityID: Building]
    public let carriers: [Carrier]
    public let ships: [Ship]
    public let routes: [EntityID: Route]
    public let economy: Economy
    public let totalPopulation: UInt64
    public let camera: Camera

    public init(
        tickCount: UInt64,
        simulatedTime: SimulationDuration,
        mapWidth: Int,
        mapHeight: Int,
        terrainGrid: [TerrainType],
        occupiedTiles: [TileCoordinate: EntityID],
        buildings: [EntityID: Building],
        carriers: [Carrier],
        ships: [Ship] = [],
        routes: [EntityID: Route] = [:],
        economy: Economy,
        totalPopulation: UInt64,
        camera: Camera
    ) {
        self.tickCount = tickCount
        self.simulatedTime = simulatedTime
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.terrainGrid = terrainGrid
        self.occupiedTiles = occupiedTiles
        self.buildings = buildings
        self.carriers = carriers
        self.ships = ships
        self.routes = routes
        self.economy = economy
        self.totalPopulation = totalPopulation
        self.camera = camera
    }

    public func terrain(at coord: TileCoordinate) -> TerrainType? {
        guard coord.x >= 0, coord.x < mapWidth, coord.y >= 0, coord.y < mapHeight else {
            return nil
        }
        return terrainGrid[coord.y * mapWidth + coord.x]
    }
}

public extension World {
    /// Extract a render-ready snapshot. O(N) in map size; intended to be
    /// called once per render frame, not once per draw call.
    func snapshot() -> WorldSnapshot {
        let pop = populations.values.reduce(UInt64(0)) { $0 + UInt64($1.population) }
        return WorldSnapshot(
            tickCount: tickCount,
            simulatedTime: simulatedTime,
            mapWidth: mapWidth,
            mapHeight: mapHeight,
            terrainGrid: terrainGrid,
            occupiedTiles: occupiedTiles,
            buildings: buildings,
            carriers: Array(carriers.values),
            ships: Array(ships.values).sorted { $0.id.raw < $1.id.raw },
            routes: routes,
            economy: economy,
            totalPopulation: pop,
            camera: camera
        )
    }
}
