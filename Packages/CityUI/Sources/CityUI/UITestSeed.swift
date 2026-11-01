import CityCore
import CityRender2D
import Foundation

/// Debug-only starting states for the Apple TV walk-through UI tests.
public enum UITestSeed {
    /// `-uiTestSeedPort`: a Renaissance game, so Seafaring is researched,
    /// with a player port on the coast nearest the town center and the
    /// camera on it. Routes and the manifest editor need a port, which the
    /// remote cannot afford to build in a fresh game.
    public static func portWorld() -> World {
        var world = World.newGame(layout: .singleIsland, seed: 0, age: .renaissance)
        world.seedUnlimitedTestInventory()
        guard let center = playerTownCenter(in: world),
              let site = nearestPortSite(in: world, around: center)
        else { return world }
        world.enqueue(.place(.port, at: site))
        _ = world.tick()
        world.camera = Camera(centerX: Double(site.x) + 0.5, centerY: Double(site.y) + 0.5, zoom: world.camera.zoom)
        return world
    }

    /// `-uiTestSeedShore`: the port seed with a shipyard on the nearest free stretch of coast, both
    /// finished, and a ship at the shipyard, under the camera on the port. Art reviews shoot the
    /// shore family from it.
    public static func shoreWorld() -> World {
        var world = portWorld()
        world.seedTestFunds()
        guard let port = world.buildings.values.first(where: { $0.kind == .port && $0.owner == .player }),
              let site = nearestSite(for: .shipyard, in: world, around: port.anchor, from: 2)
        else { return world }
        world.enqueue(.place(.shipyard, at: site))
        _ = world.tick()
        settle(&world) { $0.buildings.values.contains { [.port, .shipyard].contains($0.kind) && $0.state != .operational } }
        if let yard = world.buildings.values.first(where: { $0.kind == .shipyard && $0.owner == .player }) {
            world.emitShip(fromShipyard: yard.id)
        }
        return world
    }

    /// `-uiTestSeedOrders`: a new archipelago game with four orders on the board, two accepted and
    /// two offered, and some favour. Shots of the order board start from it (`-uiTestOpenOrders`).
    public static func ordersWorld() -> World {
        var world = World.newGame(layout: .archipelago, seed: 0)
        world.seedOrdersShowcase()
        return world
    }

    /// `-uiTestSeedFire`: the seeded town with six houses, a fire watch and a granary, two houses
    /// burning (the watch's watchman on his way to one) and two burnt to ruins, for the event art's shots.
    public static func fireWorld() -> World {
        var world = townWorld(houses: 6, showcase: [.fireWatch, .granary])
        if let watch = world.buildings.values.first(where: { $0.kind == .fireWatch }) {
            joinToRoads(watch, in: &world)
        }
        // The watchman puts out his first fire within seconds of the start, before a shot can catch him,
        // so a third house catches fire eight seconds in and sends him out again.
        world.seedFireShowcase(ruined: 2, nextIgnitionIn: fireSeedSecondCall)
        return world
    }

    /// `-uiTestSeedBlight`, `-uiTestSeedFever`, `-uiTestSeedFestival`: the lived town with a marketplace, which
    /// a festival needs, seasonal events on and `event` due, run to a tick before the season change that warns of
    /// it or asks for it, so its banner shows as the game starts.
    public static func eventWorld(_ event: SeasonalEvent) -> World {
        var world = livedTownWorld(adding: [.marketplace])
        let announcement = world.seedSeasonalEvent(event)
        while world.tickCount + 1 < announcement {
            _ = world.tick()
        }
        return world
    }

    /// Ticks from the start of `fireWorld` to its third fire.
    static let fireSeedSecondCall: UInt64 = 80

    /// Lays the shortest run of road from a tile beside `building` to the town's roads, if there is
    /// one within 8 tiles.
    private static func joinToRoads(_ building: Building, in world: inout World) {
        let roads = Set(world.buildings.values.filter { $0.kind == .road }.map(\.anchor))
        func neighbours(_ tile: TileCoordinate) -> [TileCoordinate] {
            [(1, 0), (-1, 0), (0, 1), (0, -1)].map { TileCoordinate(x: tile.x + $0.0, y: tile.y + $0.1) }
        }
        func paveable(_ tile: TileCoordinate) -> Bool {
            if case .allowed = world.canPlace(.road, at: tile) { return true }
            return false
        }
        // Breadth first from the building's sides, so the first tile that touches a road ends the shortest run.
        var cameFrom: [TileCoordinate: TileCoordinate?] = [:]
        var frontier = building.footprint.tiles(anchor: building.anchor).flatMap(neighbours).filter(paveable)
        for tile in frontier {
            cameFrom[tile] = .some(nil)
        }
        var end: TileCoordinate?
        for _ in 0 ..< 8 where end == nil {
            end = frontier.first { neighbours($0).contains(where: roads.contains) }
            var next: [TileCoordinate] = []
            for tile in frontier where end == nil {
                for step in neighbours(tile) where cameFrom[step] == nil && paveable(step) {
                    cameFrom[step] = tile
                    next.append(step)
                }
            }
            frontier = next
        }
        var run: [TileCoordinate] = []
        var cursor = end
        while let tile = cursor {
            run.append(tile)
            cursor = cameFrom[tile] ?? nil
        }
        guard !run.isEmpty else { return }
        for tile in run {
            world.enqueue(.place(.road, at: tile))
        }
        _ = world.tick()
        settle(&world) { $0.buildings.values.contains { run.contains($0.anchor) && $0.state != .operational } }
    }

    /// `-uiTestSeedTown`: the default sandbox start (single island, seed 0) with finished peasant
    /// houses beside the town center, under the default camera. Art reviews screenshot the same town
    /// before and after a sprite family changes. With a `season` (`-uiTestSeason winter`), the town
    /// ticks on until that season starts. A `showcase` (`-uiTestShowcase gather`) also places one of
    /// each listed kind at the nearest site the rules allow, for a family's before and after shots. A
    /// `culture` (`-uiTestCulture mediterranean`) builds the town in that culture's looks, and an `age`
    /// (`-uiTestAge modern`) in that age's. The title backdrop draws this town too
    /// (`TitleBackdrop.makeSnapshot`).
    public static func townWorld(
        houses: Int = 4, showcase: [BuildingKind] = [], season: Season? = nil, culture: Culture = .northernEuropean,
        age: Age = .medieval
    ) -> World {
        var world = World.newGame(layout: .singleIsland, seed: 0, culture: culture, age: age)
        world.seedUnlimitedTestInventory()
        world.seedTestFunds()
        guard let center = playerTownCenter(in: world) else {
            return world
        }
        let camera = world.camera
        var placed: Set<TileCoordinate> = []
        for kind in Array(repeating: BuildingKind.house, count: houses) + showcase {
            guard let site = nearestSite(for: kind, in: world, around: center, from: 3) else { continue }
            world.enqueue(.place(kind, at: site))
            _ = world.tick()
            placed.insert(site)
        }
        // Wait only on what the seed placed, so a starter building that never opens can't hold it up.
        settle(&world) { $0.buildings.values.contains { placed.contains($0.anchor) && $0.state != .operational } }
        // A showcase town shows no building cut off from the roads.
        // In id order, so the seed lays the same roads every run; a road laid for one building can connect the next.
        let unconnected = world.buildingIssues().filter { $0.value == .noRoad }.keys.sorted { $0.raw < $1.raw }
        for id in unconnected where world.buildingIssues()[id] == .noRoad {
            if let building = world.buildings[id], placed.contains(building.anchor) {
                joinToRoads(building, in: &world)
            }
        }
        if let season {
            for _ in 0 ..< CalendarState.ticksPerYear where world.date.season != season {
                _ = world.tick()
            }
        }
        world.camera = camera
        return world
    }

    /// The seed the launch arguments ask for, if any: `-uiTestSeedLived`, `-uiTestSeedShore`,
    /// `-uiTestSeedPort`, `-uiTestSeedArchipelago` (the largest map, seed 0, for frame times),
    /// `-uiTestSeedOrders`, `-uiTestSeedFire`, `-uiTestSeedBlight`, `-uiTestSeedFever`, `-uiTestSeedFestival` or
    /// `-uiTestSeedTown` (with `-uiTestShowcase`, `-uiTestSeason`, `-uiTestCulture` and `-uiTestAge`),
    /// checked in that order. `-uiTestCamera x,y,zoom` then moves its camera.
    public static func world(fromArguments arguments: [String]) -> World? {
        guard var world = seededWorld(fromArguments: arguments) else { return nil }
        for _ in 0 ..< seasons(fromArguments: arguments) * Int(CalendarState.ticksPerSeason) {
            _ = world.tick()
        }
        if let camera = camera(fromArguments: arguments) {
            world.camera = camera
        }
        return world
    }

    private static func seededWorld(fromArguments arguments: [String]) -> World? {
        if arguments.contains("-uiTestSeedLived") { return livedTownWorld() }
        if arguments.contains("-uiTestSeedShore") { return shoreWorld() }
        if arguments.contains("-uiTestSeedPort") { return portWorld() }
        if arguments.contains("-uiTestSeedArchipelago") { return World.newGame(layout: .archipelago, seed: 0) }
        if arguments.contains("-uiTestSeedOrders") { return ordersWorld() }
        if arguments.contains("-uiTestSeedFire") { return fireWorld() }
        if arguments.contains("-uiTestSeedBlight") { return eventWorld(.blight) }
        if arguments.contains("-uiTestSeedFever") { return eventWorld(.fever) }
        if arguments.contains("-uiTestSeedFestival") { return eventWorld(.festival) }
        guard arguments.contains("-uiTestSeedTown") else { return nil }
        return townWorld(
            showcase: showcase(fromArguments: arguments), season: season(fromArguments: arguments),
            culture: culture(fromArguments: arguments), age: age(fromArguments: arguments)
        )
    }

    /// Whether the app was launched for a test or a shot: any `-uiTest…` flag.
    public static func isActive(fromArguments arguments: [String]) -> Bool {
        arguments.contains { $0.hasPrefix("-uiTest") }
    }

    /// Where such a launch keeps its saves: a folder of its own under the temporary directory, so a
    /// test or a shot never autosaves over the player's games or fills their Continue slot. Nil for a
    /// regular launch, which `SaveStore(baseDirectory:)` reads as the player's folder.
    public static func saveDirectory(fromArguments arguments: [String]) -> URL? {
        guard isActive(fromArguments: arguments) else { return nil }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("citybuilder-ui-test-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
    }

    /// Whether a test or shot launch starts with the first-hour guide
    /// dismissed: any `-uiTest…` flag hides it, unless `-uiTestFirstSteps`
    /// asks for it (`first-hour-guidance` D2).
    public static func hidesFirstSteps(fromArguments arguments: [String]) -> Bool {
        isActive(fromArguments: arguments) && !arguments.contains("-uiTestFirstSteps")
    }

    /// `-uiTestStartGame`: skip the title and start a game at once, from the seed the other flags ask
    /// for (or a regular new game), so in-game shots need no clicks.
    public static func startsGame(fromArguments arguments: [String]) -> Bool {
        arguments.contains("-uiTestStartGame")
    }

    /// `-uiTestOpenStocks`: the started game opens with the stocks tray shown, for shots of the goods icons.
    public static func opensStocks(fromArguments arguments: [String]) -> Bool {
        arguments.contains("-uiTestOpenStocks")
    }

    /// `-uiTestOpenOrders`: the started game opens with the order board shown.
    public static func opensOrders(fromArguments arguments: [String]) -> Bool {
        arguments.contains("-uiTestOpenOrders")
    }

    /// `-uiTestOpenStatistics`: the started game opens with the Statistics sheet shown, on the tab named after it.
    public static func opensStatistics(fromArguments arguments: [String]) -> Bool {
        arguments.contains("-uiTestOpenStatistics")
    }

    /// `-uiTestOpenStatistics money|people|rivals`: the tab the Statistics sheet opens on.
    public static func statisticsTab(fromArguments arguments: [String]) -> StatisticsModel.Tab {
        guard let flag = arguments.firstIndex(of: "-uiTestOpenStatistics"), arguments.indices.contains(flag + 1),
              let tab = StatisticsModel.Tab(rawValue: arguments[flag + 1])
        else { return .goods }
        return tab
    }

    /// `-uiTestSeasons n`: the seeded game runs `n` more seasons (at most 40) before the camera
    /// goes on it, so the Statistics sheet has a history to draw.
    public static func seasons(fromArguments arguments: [String]) -> Int {
        guard let flag = arguments.firstIndex(of: "-uiTestSeasons"), arguments.indices.contains(flag + 1),
              let count = Int(arguments[flag + 1])
        else { return 0 }
        return min(max(count, 0), StatisticsHistory.capacity)
    }

    /// `-uiTestShowStats`: frame rate, node and draw counts in the corner of the map, for performance shots.
    public static func showsStats(fromArguments arguments: [String]) -> Bool {
        arguments.contains("-uiTestShowStats")
    }

    /// `-uiTestPlace kind@x,y`: the building a started game arms, and the tile its ghost stands on, so
    /// shots of placing need no input. A kind the world has not researched yet shows a red ghost.
    public static func placement(fromArguments arguments: [String]) -> (kind: BuildingKind, tile: TileCoordinate)? {
        guard let flag = arguments.firstIndex(of: "-uiTestPlace"), arguments.indices.contains(flag + 1) else { return nil }
        let parts = arguments[flag + 1].split(separator: "@")
        guard parts.count == 2, let kind = BuildingKind(rawValue: String(parts[0])), let tile = tile(String(parts[1])) else { return nil }
        return (kind, tile)
    }

    /// `-uiTestSelect x,y`: the tile a started game selects with the inspect tool.
    public static func selection(fromArguments arguments: [String]) -> TileCoordinate? {
        guard let flag = arguments.firstIndex(of: "-uiTestSelect"), arguments.indices.contains(flag + 1) else { return nil }
        return tile(arguments[flag + 1])
    }

    private static func tile(_ value: String) -> TileCoordinate? {
        let values = value.split(separator: ",").compactMap { Int($0) }
        return values.count == 2 ? TileCoordinate(x: values[0], y: values[1]) : nil
    }

    /// The camera after `-uiTestCamera x,y,zoom` (tile coordinates and zoom), if any.
    public static func camera(fromArguments arguments: [String]) -> Camera? {
        guard let flag = arguments.firstIndex(of: "-uiTestCamera"), arguments.indices.contains(flag + 1) else { return nil }
        let values = arguments[flag + 1].split(separator: ",").compactMap { Double($0) }
        guard values.count == 3 else { return nil }
        return Camera(centerX: values[0], centerY: values[1], zoom: values[2])
    }

    /// `-uiTestSeedLived`: the town seed with two farms and the fire trades, every free tile within
    /// six of the town center paved, and 300 ticks run, so the houses hold residents and the
    /// workshops work. In-game checks of ambient life (smoke, strollers) start from it. `adding` places
    /// more kinds with the showcase.
    public static func livedTownWorld(adding extra: [BuildingKind] = []) -> World {
        var world = townWorld(showcase: [.farm, .farm, .bakery, .smelter, .brewery, .toolsmith] + extra)
        guard let center = playerTownCenter(in: world) else {
            return world
        }
        let camera = world.camera
        for dy in -6 ... 6 {
            for dx in -6 ... 6 {
                let tile = TileCoordinate(x: center.x + dx, y: center.y + dy)
                if case .allowed = world.canPlace(.road, at: tile) { world.enqueue(.place(.road, at: tile)) }
            }
        }
        for _ in 0 ..< 300 {
            _ = world.tick()
        }
        world.camera = camera
        return world
    }

    /// Every kind in the build category after `-uiTestShowcase` (`gather`, `craft`, `town`), or the
    /// kinds it lists by raw value (`lumberjack-hut,sawmill`), if any.
    public static func showcase(fromArguments arguments: [String]) -> [BuildingKind] {
        guard let flag = arguments.firstIndex(of: "-uiTestShowcase"), arguments.indices.contains(flag + 1) else { return [] }
        let value = arguments[flag + 1]
        let category = BuildingKind.allCases.filter { $0.category == value }
        return category.isEmpty ? value.split(separator: ",").compactMap { BuildingKind(rawValue: String($0)) } : category
    }

    private static func playerTownCenter(in world: World) -> TileCoordinate? {
        world.buildings.values.first { $0.kind == .townCenter && $0.owner == .player }?.anchor
    }

    /// Ticks `world` while `pending` holds, for at most 2000 ticks.
    private static func settle(_ world: inout World, while pending: (World) -> Bool) {
        var ticks = 0
        while pending(world), ticks < 2000 {
            _ = world.tick()
            ticks += 1
        }
    }

    /// The closest tile to `center`, ring by ring from `radius`, where `kind` may be placed.
    private static func nearestSite(
        for kind: BuildingKind,
        in world: World,
        around center: TileCoordinate,
        from radius: Int
    ) -> TileCoordinate? {
        for ring in radius ..< 16 {
            for dy in -ring ... ring {
                for dx in -ring ... ring where max(abs(dx), abs(dy)) == ring {
                    let tile = TileCoordinate(x: center.x + dx, y: center.y + dy)
                    if case .allowed = world.canPlace(kind, at: tile) { return tile }
                }
            }
        }
        return nil
    }

    /// The age after `-uiTestAge` in the launch arguments, medieval if none.
    public static func age(fromArguments arguments: [String]) -> Age {
        guard let flag = arguments.firstIndex(of: "-uiTestAge"), arguments.indices.contains(flag + 1) else { return .medieval }
        return Age(rawValue: arguments[flag + 1]) ?? .medieval
    }

    /// The culture after `-uiTestCulture` in the launch arguments, Northern European if none.
    public static func culture(fromArguments arguments: [String]) -> Culture {
        guard let flag = arguments.firstIndex(of: "-uiTestCulture"), arguments.indices.contains(flag + 1) else { return .northernEuropean }
        return Culture(rawValue: arguments[flag + 1]) ?? .northernEuropean
    }

    /// The season after `-uiTestSeason` in the launch arguments, if any.
    public static func season(fromArguments arguments: [String]) -> Season? {
        guard let flag = arguments.firstIndex(of: "-uiTestSeason"), arguments.indices.contains(flag + 1) else { return nil }
        return Season.allCases.first { arguments[flag + 1] == "\($0)" }
    }

    private static func nearestPortSite(in world: World, around center: TileCoordinate) -> TileCoordinate? {
        for radius in 0 ..< 40 {
            for dy in -radius ... radius {
                for dx in -radius ... radius where max(abs(dx), abs(dy)) == radius {
                    let tile = TileCoordinate(x: center.x + dx, y: center.y + dy)
                    if case .allowed = world.canPlace(.port, at: tile) {
                        return tile
                    }
                }
            }
        }
        return nil
    }
}
