import Foundation
@testable import CityCore

/// The PlayerBot's events kit (`add-event-counterplay` D12), for fire
/// season: while a fire is warned or under way it builds a fire watch by
/// the first house or workshop no watch covers, one a turn, so every
/// 8-tile cluster ends up with one. Blight, fever and the festival answers
/// come with their mechanics (sections 5 and 6).
struct EventsKit {
    /// What a watch costs on top of its price before the kit builds it.
    static let cushion: Int64 = 50
    /// How far from the uncovered building the kit looks for a plot, in tiles.
    static let searchReach = 4

    private(set) var watchesBuilt = 0

    mutating func takeTurn(_ world: inout World) {
        guard Self.isFireSeason(world), let target = Self.uncovered(in: world) else { return }
        let price = BuildingCatalog.spec(for: .fireWatch).cost + Self.cushion
        guard world.economy.balance >= price, let anchor = Self.plot(near: target, in: world) else { return }
        world.enqueue(.place(.fireWatch, at: anchor))
        watchesBuilt += 1
    }

    static func isFireSeason(_ world: World) -> Bool {
        world.currentSeasonalEvent?.event.effect == .fire
    }

    /// The lowest-ID player house or workshop with no fire watch, built or
    /// building, within reach.
    static func uncovered(in world: World) -> Building? {
        let watches = world.buildings.values.filter { $0.kind == .fireWatch && $0.owner == .player }
        return world.buildings.values
            .filter { $0.owner == .player && $0.state != .constructing && World.canIgnite($0.kind) }
            .sorted { $0.id.raw < $1.id.raw }
            .first { building in !watches.contains { World.footprintDistance($0, building) <= World.fireWatchReach } }
    }

    /// The first free plot by a road that reaches `target`, ring by ring
    /// out from its footprint.
    static func plot(near target: Building, in world: World) -> TileCoordinate? {
        let box = target.bounds
        for ring in 1 ... searchReach {
            for y in (box.minY - ring) ... (box.maxY + ring) {
                for x in (box.minX - ring) ... (box.maxX + ring) where max(box.minX - x, x - box.maxX, box.minY - y, y - box.maxY) == ring {
                    let tile = TileCoordinate(x: x, y: y)
                    guard world.canPlace(.fireWatch, at: tile) == .allowed,
                          world.sharesRoadNetwork(tile, .single, with: target.anchor, target.footprint)
                    else { continue }
                    return tile
                }
            }
        }
        return nil
    }
}
