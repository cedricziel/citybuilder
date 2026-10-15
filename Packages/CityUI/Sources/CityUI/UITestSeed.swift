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
