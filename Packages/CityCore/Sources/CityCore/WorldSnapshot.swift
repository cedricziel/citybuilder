import Foundation

/// Per-island aggregate exposed in `WorldSnapshot.islandSummaries`.
/// Sums goods-buffer (warehouse / port / shipyard) stockpiles by good
/// for every building anchored on the island. Producer-internal
/// stockpiles (sawmill / lumberjack hut output buffers) are excluded.
public struct IslandSummary: Hashable, Sendable {
    public let id: IslandID
    public let name: String
    public let bounds: TileBoundingBox
    /// Aggregate stockpile in good-buffer buildings on this island.
    public let stockpile: [Good: Int]
    /// Aggregate total capacity in good-buffer buildings on this
    /// island. With mixed-storage `Stockpile`, every good in the
    /// catalog receives the same total — buildings don't specialize.
    public let capacity: [Good: Int]

    public init(
        id: IslandID,
        name: String,
        bounds: TileBoundingBox,
        stockpile: [Good: Int] = [:],
        capacity: [Good: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.bounds = bounds
        self.stockpile = stockpile
        self.capacity = capacity
    }
}

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
    /// Per-island aggregate keyed by `IslandID`. Producer-internal
    /// stockpiles are excluded; only warehouse / port / shipyard count.
    public let islandSummaries: [IslandID: IslandSummary]
    /// Cached tile→island map backing `island(at:)`. O(1) lookups.
    let tileToIsland: [TileCoordinate: IslandID]

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
        camera: Camera,
        islandSummaries: [IslandID: IslandSummary] = [:],
        tileToIsland: [TileCoordinate: IslandID] = [:]
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
        self.islandSummaries = islandSummaries
        self.tileToIsland = tileToIsland
    }

    public func terrain(at coord: TileCoordinate) -> TerrainType? {
        guard coord.x >= 0, coord.x < mapWidth, coord.y >= 0, coord.y < mapHeight else {
            return nil
        }
        return terrainGrid[coord.y * mapWidth + coord.x]
    }

    /// Returns the `IslandID` of the island containing the given tile,
    /// or `nil` when the tile is water (or outside any island's
    /// buildable footprint).
    public func island(at coord: TileCoordinate) -> IslandID? {
        tileToIsland[coord]
    }
}

public extension World {
    /// Extract a render-ready snapshot. O(N) in map size; intended to be
    /// called once per render frame, not once per draw call.
    func snapshot() -> WorldSnapshot {
        let pop = populations.values.reduce(UInt64(0)) { $0 + UInt64($1.population) }
        let tileToIsland = IslandDetector.detect(
            width: mapWidth,
            height: mapHeight,
            terrain: terrainGrid,
            mapHeightForClimate: mapHeight,
            seed: seed
        ).tileToIsland
        let summaries = buildIslandSummaries(tileToIsland: tileToIsland)
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
            camera: camera,
            islandSummaries: summaries,
            tileToIsland: tileToIsland
        )
    }

    /// Building kinds whose stockpiles count toward island aggregates.
    /// Producer-internal output buffers (sawmill, lumberjack hut) are
    /// excluded — those are in-transit. The town center is included
    /// because it's the bootstrap goods-buffer that holds the starter
    /// inventory players spend on their first placements.
    private static let goodsBufferKinds: Set<BuildingKind> = [
        .warehouse, .port, .shipyard, .townCenter
    ]

    private func buildIslandSummaries(
        tileToIsland: [TileCoordinate: IslandID]
    ) -> [IslandID: IslandSummary] {
        var stockpileByIsland: [IslandID: [Good: Int]] = [:]
        var capacityTotalByIsland: [IslandID: Int] = [:]
        for (id, building) in buildings {
            guard Self.goodsBufferKinds.contains(building.kind) else { continue }
            guard let islandID = islandID(forBuilding: building, tileToIsland: tileToIsland)
            else { continue }
            if let stockpile = stockpiles[id] {
                for (good, amount) in stockpile.contents where amount > 0 {
                    stockpileByIsland[islandID, default: [:]][good, default: 0] += amount
                }
                capacityTotalByIsland[islandID, default: 0] += stockpile.capacity
            }
        }
        var summaries: [IslandID: IslandSummary] = [:]
        summaries.reserveCapacity(islands.count)
        for island in islands {
            let stocks = stockpileByIsland[island.id] ?? [:]
            let total = capacityTotalByIsland[island.id] ?? 0
            var capacity: [Good: Int] = [:]
            if total > 0 {
                for good in Good.allCases {
                    capacity[good] = total
                }
            }
            summaries[island.id] = IslandSummary(
                id: island.id,
                name: island.name,
                bounds: island.bounds,
                stockpile: stocks,
                capacity: capacity
            )
        }
        return summaries
    }

    /// Resolve a building's island via its first footprint tile that
    /// resolves in the tile-to-island map. Shore-placement buildings
    /// straddle land+water; their land-face tiles map to an island,
    /// their sea-face tiles do not.
    private func islandID(
        forBuilding building: Building,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> IslandID? {
        let spec = BuildingCatalog.spec(for: building.kind)
        for tile in spec.footprint.tiles(anchor: building.anchor) {
            if let id = tileToIsland[tile] { return id }
        }
        return nil
    }
}
