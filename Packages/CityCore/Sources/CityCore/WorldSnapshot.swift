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
    /// Aggregate capacity for each good in good-buffer buildings on this
    /// island: a store's per-good limit, or a shared stockpile's whole
    /// capacity, which any one good could fill.
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
    /// Mutable so a renderer can show a still world at another time of day.
    public var tickCount: UInt64
    public let simulatedTime: SimulationDuration
    public let mapWidth: Int
    public let mapHeight: Int
    public let terrainGrid: [TerrainType]
    public let occupiedTiles: [TileCoordinate: EntityID]
    public let buildings: [EntityID: Building]
    public let carriers: [Carrier]
    /// Market porters out, in entity order. Spec: `rendering-2_5d` /
    /// Market porters render.
    public let porters: [Porter]
    public let ships: [Ship]
    public let routes: [EntityID: Route]
    public let economy: Economy
    public let totalPopulation: UInt64
    /// Mutable so a renderer can move the view over a still world.
    public var camera: Camera
    /// Per-island aggregate keyed by `IslandID`. Producer-internal
    /// stockpiles are excluded; only warehouse / port / shipyard count.
    public let islandSummaries: [IslandID: IslandSummary]
    /// Cached tile→island map backing `island(at:)`. O(1) lookups.
    let tileToIsland: [TileCoordinate: IslandID]
    /// Non-road buildings with no road tile orthogonally adjacent to
    /// their footprint. Spec: `rendering-2_5d` / Road-access marker.
    /// Mutable so a still backdrop can hide the warning markers.
    public var roadDisconnectedBuildings: Set<EntityID>
    /// Why idle player buildings are idle. Spec:
    /// `warehouses-and-logistics` / Buildings report why they are idle.
    public let buildingIssues: [EntityID: BuildingIssue]
    /// Trees in reach of each player lumberjack hut and open grass in
    /// reach of each player forester. Spec: `forestry` / Trees and open
    /// ground in reach.
    public let catchments: [EntityID: Int]
    /// Population state of every house, keyed by building. Spec:
    /// `rendering-2_5d` / Houses render their tier.
    public let housePopulations: [EntityID: HousePopulation]
    /// Spec: `calendar-and-events` / The world has a date.
    public let date: GameDate
    /// Spec: `cultures` / Snapshot carries the culture.
    public let culture: Culture
    /// Spec: `historical-ages` / Snapshot carries the age.
    public let age: Age
    /// Houses under a signature effect; others are absent. Spec:
    /// `age-signatures`.
    public let houseModifiers: [EntityID: HouseModifiers]
    /// Every rival town, by ID. Spec: `rendering-2_5d` / Buildings render
    /// in their owner's culture.
    public let rivals: [RivalSummary]
    /// The town market's goods, prices and what is left this season, in
    /// catalog order. Spec: `town-market` / Market trades are reported.
    public let market: [MarketQuote]
    /// The player's finished seasons. Spec: `statistics` / The Statistics sheet.
    public let statistics: StatisticsHistory
    /// The order board, favour and the shipments on the road. Spec:
    /// `platform-shells` / Order board.
    public let orders: OrdersState
    /// The seasonal event warned or under way, with its onset season.
    /// Spec: `platform-shells` / Seasonal events show banners and a chip.
    public let seasonalEvent: SeasonalEventOnset?
    /// Turns any tick into a date, such as when ruins burnt down.
    public let calendar: CalendarState
    /// The area a blight or fever threatens, from its warning to its end.
    public let markedArea: MarkedArea?
    /// The player's crop fields a blight slows now.
    public let blightedFields: Set<EntityID>
    /// The player's houses a fever holds back now.
    public let feverHouses: Set<EntityID>
    /// The first season of a festival: the player's plaza fills (#127).
    public let isFestivalCrowd: Bool
    /// True once the seasonal event has started, false while it is only warned.
    public let isSeasonalEventUnderWay: Bool
    /// The flammable buildings each fire watch would answer. Spec:
    /// `platform-shells` / Fire watch inspector.
    public let fireWatchCover: [EntityID: Int]
    /// Fire watchmen walking to a fire or dousing it. Spec: `rendering-2_5d` /
    /// Seasonal events are drawn on the map.
    public let watchmen: [WatchmanWalker]

    public init(
        tickCount: UInt64,
        simulatedTime: SimulationDuration,
        mapWidth: Int,
        mapHeight: Int,
        terrainGrid: [TerrainType],
        occupiedTiles: [TileCoordinate: EntityID],
        buildings: [EntityID: Building],
        carriers: [Carrier],
        porters: [Porter] = [],
        ships: [Ship] = [],
        routes: [EntityID: Route] = [:],
        economy: Economy,
        totalPopulation: UInt64,
        camera: Camera,
        islandSummaries: [IslandID: IslandSummary] = [:],
        tileToIsland: [TileCoordinate: IslandID] = [:],
        roadDisconnectedBuildings: Set<EntityID> = [],
        buildingIssues: [EntityID: BuildingIssue] = [:],
        catchments: [EntityID: Int] = [:],
        housePopulations: [EntityID: HousePopulation] = [:],
        date: GameDate = GameDate(year: 1200, season: .spring),
        culture: Culture = .northernEuropean,
        age: Age = .medieval,
        houseModifiers: [EntityID: HouseModifiers] = [:],
        rivals: [RivalSummary] = [],
        market: [MarketQuote] = [],
        statistics: StatisticsHistory = StatisticsHistory(),
        orders: OrdersState = OrdersState(),
        seasonalEvent: SeasonalEventOnset? = nil,
        calendar: CalendarState = .inactive,
        watchmen: [WatchmanWalker] = [],
        markedArea: MarkedArea? = nil,
        blightedFields: Set<EntityID> = [],
        feverHouses: Set<EntityID> = [],
        isFestivalCrowd: Bool = false,
        isSeasonalEventUnderWay: Bool = false,
        fireWatchCover: [EntityID: Int] = [:]
    ) {
        self.tickCount = tickCount
        self.simulatedTime = simulatedTime
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.terrainGrid = terrainGrid
        self.occupiedTiles = occupiedTiles
        self.buildings = buildings
        self.carriers = carriers
        self.porters = porters
        self.ships = ships
        self.routes = routes
        self.economy = economy
        self.totalPopulation = totalPopulation
        self.camera = camera
        self.islandSummaries = islandSummaries
        self.tileToIsland = tileToIsland
        self.roadDisconnectedBuildings = roadDisconnectedBuildings
        self.buildingIssues = buildingIssues
        self.catchments = catchments
        self.housePopulations = housePopulations
        self.date = date
        self.culture = culture
        self.age = age
        self.houseModifiers = houseModifiers
        self.rivals = rivals
        self.market = market
        self.statistics = statistics
        self.orders = orders
        self.seasonalEvent = seasonalEvent
        self.calendar = calendar
        self.watchmen = watchmen
        self.markedArea = markedArea
        self.blightedFields = blightedFields
        self.feverHouses = feverHouses
        self.isFestivalCrowd = isFestivalCrowd
        self.isSeasonalEventUnderWay = isSeasonalEventUnderWay
        self.fireWatchCover = fireWatchCover
    }

    public func rival(_ id: RivalID) -> RivalSummary? {
        rivals.first { $0.id == id }
    }

    /// The rival seated on the island, nil for the player's islands.
    public func rival(onIsland islandID: IslandID) -> RivalSummary? {
        rivals.first { $0.islandID == islandID }
    }

    /// The owner's culture: the world's for the player.
    public func culture(for owner: Owner) -> Culture {
        owner.rivalID.flatMap { rival($0)?.culture } ?? culture
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

/// What the renderer and UI need of a rival town (design D10).
public struct RivalSummary: Hashable, Sendable {
    public let id: RivalID
    public let name: String
    public let colour: RivalColour
    public let culture: Culture
    public let age: Age
    public let islandID: IslandID
    /// Goods across the rival's buffers, which its market offers come
    /// from (`add-rival-trade` D5).
    public let stock: [Good: Int]
    /// Price improvement from the player's favour with this rival, in percent.
    public let priceBonusPercent: Int

    public init(_ rival: RivalTown, stock: [Good: Int] = [:], priceBonusPercent: Int = 0) {
        id = rival.id
        name = rival.name
        colour = rival.colour
        culture = rival.culture
        age = rival.age
        islandID = rival.islandID
        self.stock = stock
        self.priceBonusPercent = priceBonusPercent
    }

    public var sellOffers: [RivalOffer] {
        RivalMarket.sellOffers(stock: stock, bonusPercent: priceBonusPercent)
    }

    public var buyOffers: [RivalOffer] {
        RivalMarket.buyOffers(stock: stock, bonusPercent: priceBonusPercent)
    }
}

public extension World {
    /// Extract a render-ready snapshot. O(N) in map size; intended to be
    /// called once per render frame, not once per draw call.
    func snapshot() -> WorldSnapshot {
        let pop = UInt64(population(of: .player))
        let tileToIsland = tileToIslandMap()
        let summaries = buildIslandSummaries(tileToIsland: tileToIsland)
        return WorldSnapshot(
            tickCount: tickCount,
            simulatedTime: simulatedTime,
            mapWidth: mapWidth,
            mapHeight: mapHeight,
            terrainGrid: terrainGrid,
            occupiedTiles: occupiedTiles,
            buildings: buildings,
            carriers: Array(carriers.values) + orders.shipments.map(\.asCarrier),
            porters: porters,
            ships: Array(ships.values).sorted { $0.id.raw < $1.id.raw },
            routes: routes,
            economy: economy,
            totalPopulation: pop,
            camera: camera,
            islandSummaries: summaries,
            tileToIsland: tileToIsland,
            roadDisconnectedBuildings: roadDisconnectedBuildings(),
            buildingIssues: buildingIssues(tileToIsland: tileToIsland),
            catchments: catchmentCounts(tileToIsland: tileToIsland),
            housePopulations: populations,
            date: date,
            culture: culture,
            age: age,
            houseModifiers: snapshotHouseModifiers(),
            rivals: rivals.map { RivalSummary($0, stock: rivalStock($0.id), priceBonusPercent: rivalPriceBonusPercent($0.id)) },
            market: marketQuotes,
            statistics: statistics,
            orders: orders,
            seasonalEvent: currentSeasonalEvent,
            calendar: calendar,
            watchmen: watchmenAtWork,
            markedArea: seasonalEvents.marked,
            blightedFields: Set(buildings.values.filter(isBlighted).map(\.id)),
            feverHouses: Set(feverHouses().map(\.id)),
            isFestivalCrowd: isFestivalCrowd,
            isSeasonalEventUnderWay: seasonalEvents.active != nil,
            fireWatchCover: fireWatchCoverCounts()
        )
    }

    private func snapshotHouseModifiers() -> [EntityID: HouseModifiers] {
        let sources = activeSignatureSources()
        guard !sources.isEmpty else { return [:] }
        var result: [EntityID: HouseModifiers] = [:]
        for house in buildings.values where house.kind == .house {
            let modifiers = houseModifiers(of: house, sources: sources)
            if modifiers != .none { result[house.id] = modifiers }
        }
        return result
    }

    private func roadDisconnectedBuildings() -> Set<EntityID> {
        Set(buildings.values.lazy.filter { building in
            building.kind != .road && building.kind != .ruins && !roadGraph.isAnchorRoadConnected(
                building.anchor,
                footprint: building.footprint
            )
        }.map(\.id))
    }

    private func buildIslandSummaries(
        tileToIsland: [TileCoordinate: IslandID]
    ) -> [IslandID: IslandSummary] {
        var stockpileByIsland: [IslandID: [Good: Int]] = [:]
        var capacityByIsland: [IslandID: [Good: Int]] = [:]
        for (id, building) in buildings {
            guard Self.placementBufferKinds.contains(building.kind),
                  let islandID = islandID(forBuilding: building, tileToIsland: tileToIsland)
            else { continue }
            if let stockpile = stockpiles[id] {
                for (good, amount) in stockpile.contents where amount > 0 {
                    stockpileByIsland[islandID, default: [:]][good, default: 0] += amount
                }
                if stockpile.capacity > 0 {
                    for good in Good.allCases where stockpile.accepts(good) {
                        capacityByIsland[islandID, default: [:]][good, default: 0] += stockpile.capacity
                    }
                }
            }
        }
        var summaries: [IslandID: IslandSummary] = [:]
        summaries.reserveCapacity(islands.count)
        for island in islands {
            let stocks = stockpileByIsland[island.id] ?? [:]
            let capacity = capacityByIsland[island.id] ?? [:]
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
