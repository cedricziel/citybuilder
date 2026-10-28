@testable import CityCore

// Shared fixture for the `add-orders` tests.

/// A grass map with a player town center, a road running south from it and
/// a warehouse beside the road, with the calendar on. Output history is
/// seeded just before a season boundary, because the statistics system
/// closes real (empty) seasons as the fixture runs.
struct OrdersFixture {
    var world: World
    let center: EntityID
    let warehouse: EntityID
    /// The road tile the warehouse touches.
    let warehouseRoad: TileCoordinate

    init(difficulty: Difficulty = .normal, age: Age = .medieval, calendarOn: Bool = true) {
        var world = World.fixtureWithTerrain(width: 40, height: 40, fill: .grass, seed: 3)
        world.islands = IslandDetector.detectIslands(
            width: world.mapWidth, height: world.mapHeight, terrain: world.terrainGrid,
            mapHeightForClimate: world.mapHeight, seed: 3
        )
        world.difficulty = difficulty
        world.age = age
        world.calendar = CalendarState(startYear: 1200, isActive: calendarOn)
        world.testMaterialCredits = [:]
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        let anchor = TileCoordinate(x: 10, y: 10)
        center = world.testPlace(.townCenter, at: anchor, owner: .player)
        let roadX = anchor.x + footprint.width
        for y in anchor.y ... anchor.y + 20 {
            world.testRoad(at: TileCoordinate(x: roadX, y: y))
        }
        warehouseRoad = TileCoordinate(x: roadX, y: anchor.y + 15)
        warehouse = world.testPlace(.warehouse, at: TileCoordinate(x: roadX + 1, y: anchor.y + 14), owner: .player)
        self.world = world
    }

    /// Four closed seasons in which the player made `perSeason` units of each good.
    mutating func seedOutput(_ output: [Good: Int]) {
        world.statistics.seasons = (0 ..< 4).map { season in
            var record = SeasonStatistics()
            record.season = season
            for (good, made) in output {
                record.goods[good] = GoodFlow.made(made)
            }
            return record
        }
    }

    /// Runs to just before `tick` and returns the events of the ticks run.
    @discardableResult
    mutating func run(to tick: UInt64) -> [WorldEvent] {
        var events: [WorldEvent] = []
        while world.tickCount < tick {
            events += world.tick().events
        }
        return events
    }

    /// Crosses the boundary of `season` with `output` as the last four seasons' output.
    @discardableResult
    mutating func cross(season: Int, output: [Good: Int]) -> [WorldEvent] {
        let boundary = UInt64(season) * CalendarState.ticksPerSeason
        var events = run(to: boundary - 1)
        seedOutput(output)
        events += run(to: boundary)
        return events
    }

    var orders: [Order] {
        world.orders.orders
    }

    mutating func setStock(_ stock: [Good: Int], in building: EntityID) {
        world.testSetStock(stock, in: building)
    }

    func stock(_ good: Good, in building: EntityID) -> Int {
        world.stockpiles[building]?.quantity(of: good) ?? 0
    }

    /// The seasons in `range` at whose boundary the orders list grew.
    mutating func issueSeasons(_ range: ClosedRange<Int>, output: [Good: Int] = [.planks: 30]) -> [Int] {
        var seasons: [Int] = []
        for season in range {
            let before = world.orders.orders.count
            cross(season: season, output: output)
            if world.orders.orders.count > before { seasons.append(season) }
        }
        return seasons
    }
}

extension GoodFlow {
    static func made(_ units: Int) -> GoodFlow {
        var flow = GoodFlow()
        flow.made = units
        return flow
    }
}

extension World {
    /// A road tile, as `seedStarterRoads` lays one.
    mutating func testRoad(at tile: TileCoordinate) {
        let id = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        buildings[id] = Building(id: id, kind: .road, anchor: tile, state: .operational, ticksSincePlacement: 0)
        occupiedTiles[tile] = id
        roadGraph.addRoad(at: tile)
    }

    /// Adds an order with the template's other fields, bypassing issuing.
    @discardableResult
    mutating func testAddOrder(
        _ issuer: OrderIssuer = .crown, good: Good = .planks, quantity: Int = 30,
        state: OrderState = .offered, reward: Int64 = 240, deadline: UInt64? = nil,
        favourGain: Int = 2, favourLoss: Int = 2
    ) -> OrderID {
        let id = orders.nextOrderRaw
        orders.nextOrderRaw += 1
        orders.orders.append(Order(
            id: id, template: issuer == .crown ? .crownTimber : .rivalTimber, issuer: issuer, good: good,
            quantity: quantity, reward: reward, favourGain: favourGain, favourLoss: favourLoss,
            issuedTick: tickCount, offerEndsTick: tickCount + 10 * CalendarState.ticksPerSeason,
            deadlineTick: deadline ?? tickCount + 2 * CalendarState.ticksPerSeason, state: state
        ))
        return id
    }

    func order(_ id: OrderID) -> Order? {
        orders.orders.first { $0.id == id }
    }
}
