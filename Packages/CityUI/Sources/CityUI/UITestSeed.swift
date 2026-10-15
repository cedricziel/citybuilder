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
        guard let center = world.buildings.values.first(where: { $0.kind == .townCenter && $0.owner == .player })?.anchor,
              let site = nearestPortSite(in: world, around: center)
        else { return world }
        world.enqueue(.place(.port, at: site))
        _ = world.tick()
        world.camera = Camera(centerX: Double(site.x) + 0.5, centerY: Double(site.y) + 0.5, zoom: world.camera.zoom)
        return world
    }

    /// `-uiTestSeedTown`: the default sandbox start (single island, seed 0) with finished peasant
    /// houses beside the town center, under the default camera. Art reviews screenshot the same town
    /// before and after a sprite family changes. With a `season` (`-uiTestSeason winter`), the town
    /// ticks on until that season starts. A `showcase` (`-uiTestShowcase gather`) also places one of
    /// each listed kind at the nearest site the rules allow, for a family's before and after shots.
    public static func townWorld(houses: Int = 4, showcase: [BuildingKind] = [], season: Season? = nil) -> World {
        var world = World.newGame(layout: .singleIsland, seed: 0)
        world.seedUnlimitedTestInventory()
        guard let center = world.buildings.values.first(where: { $0.kind == .townCenter && $0.owner == .player })?.anchor else {
            return world
        }
        let camera = world.camera
        for kind in Array(repeating: BuildingKind.house, count: houses) + showcase {
            guard let site = nearestSite(for: kind, in: world, around: center, from: 3) else { continue }
            world.enqueue(.place(kind, at: site))
            _ = world.tick()
        }
        for _ in 0 ..< 2000 where world.buildings.values.contains(where: { $0.owner == .player && $0.state != .operational }) {
            _ = world.tick()
        }
        if let season {
            for _ in 0 ..< CalendarState.ticksPerYear where world.date.season != season {
                _ = world.tick()
            }
        }
        world.camera = camera
        return world
    }

    /// Every kind in the build category after `-uiTestShowcase` (`gather`, `craft`, `town`), if any.
    public static func showcase(fromArguments arguments: [String]) -> [BuildingKind] {
        guard let flag = arguments.firstIndex(of: "-uiTestShowcase"), arguments.indices.contains(flag + 1) else { return [] }
        return BuildingKind.allCases.filter { $0.category == arguments[flag + 1] }
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
