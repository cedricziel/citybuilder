import CityCore
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

    /// `-uiTestSeedTown`: the default sandbox start (single island, seed 0) with finished peasant
    /// houses beside the town center, under the default camera. Art reviews screenshot the same town
    /// before and after a sprite family changes. With a `season` (`-uiTestSeason winter`), the town
    /// ticks on until that season starts. A `showcase` (`-uiTestShowcase gather`) also places one of
    /// each listed kind at the nearest site the rules allow, for a family's before and after shots. A `culture`
    /// (`-uiTestCulture mediterranean`) builds the town in that culture's looks. The title backdrop draws
    /// this town too (`TitleBackdrop.makeSnapshot`).
    public static func townWorld(
        houses: Int = 4, showcase: [BuildingKind] = [], season: Season? = nil, culture: Culture = .northernEuropean
    ) -> World {
        var world = World.newGame(layout: .singleIsland, seed: 0, culture: culture)
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
        if let season {
            for _ in 0 ..< CalendarState.ticksPerYear where world.date.season != season {
                _ = world.tick()
            }
        }
        world.camera = camera
        return world
    }

    /// The seed the launch arguments ask for, if any: `-uiTestSeedLived`, `-uiTestSeedShore`,
    /// `-uiTestSeedPort` or `-uiTestSeedTown` (with `-uiTestShowcase` and `-uiTestSeason`), checked in
    /// that order. `-uiTestCamera x,y,zoom` then moves its camera.
    public static func world(fromArguments arguments: [String]) -> World? {
        guard var world = seededWorld(fromArguments: arguments) else { return nil }
        if let camera = camera(fromArguments: arguments) {
            world.camera = camera
        }
        return world
    }

    private static func seededWorld(fromArguments arguments: [String]) -> World? {
        if arguments.contains("-uiTestSeedLived") { return livedTownWorld() }
        if arguments.contains("-uiTestSeedShore") { return shoreWorld() }
        if arguments.contains("-uiTestSeedPort") { return portWorld() }
        guard arguments.contains("-uiTestSeedTown") else { return nil }
        return townWorld(
            showcase: showcase(fromArguments: arguments), season: season(fromArguments: arguments),
            culture: culture(fromArguments: arguments)
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

    /// `-uiTestStartGame`: skip the title and start a game at once, from the seed the other flags ask
    /// for (or a regular new game), so in-game shots need no clicks.
    public static func startsGame(fromArguments arguments: [String]) -> Bool {
        arguments.contains("-uiTestStartGame")
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
    /// workshops work. In-game checks of ambient life (smoke, strollers) start from it.
    public static func livedTownWorld() -> World {
        var world = townWorld(showcase: [.farm, .farm, .bakery, .smelter, .brewery, .toolsmith])
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

    /// Every kind in the build category after `-uiTestShowcase` (`gather`, `craft`, `town`), if any.
    public static func showcase(fromArguments arguments: [String]) -> [BuildingKind] {
        guard let flag = arguments.firstIndex(of: "-uiTestShowcase"), arguments.indices.contains(flag + 1) else { return [] }
        return BuildingKind.allCases.filter { $0.category == arguments[flag + 1] }
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
