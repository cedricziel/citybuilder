import Foundation
@testable import CityCore

/// The PlayerBot's events kit (`add-event-counterplay` D12), for fire
/// season: while a fire is warned or under way it builds a fire watch by
/// the first house or workshop no watch covers that has a plot, one a turn, so every
/// 8-tile cluster ends up with one. Blight, fever and the festival answers
/// come with their mechanics (sections 5 and 6).
struct EventsKit {
    /// What a watch costs on top of its price before the kit builds it.
    static let cushion: Int64 = 50
    /// How far from the uncovered building the kit looks for a plot, in tiles.
    static let searchReach = 4

    /// Watches the kit placed that stand: counted once the placement
    /// succeeded, at the kit's next turn.
    private(set) var watchesBuilt = 0
    /// Where the last placement went, until the kit sees whether it stood.
    private var placed: TileCoordinate?
    /// Buildings with no plot a watch would cover from, not tried again.
    private var tried: Set<EntityID> = []

    mutating func takeTurn(_ world: inout World) {
        if let anchor = placed {
            placed = nil
            if let id = world.occupiedTiles[anchor], world.buildings[id]?.kind == .fireWatch { watchesBuilt += 1 }
        }
        let price = BuildingCatalog.spec(for: .fireWatch).cost + Self.cushion
        guard Self.isFireSeason(world), world.economy.balance >= price else { return }
        for target in Self.uncovered(in: world) where !tried.contains(target.id) {
            guard let anchor = Self.plot(near: target, in: world) else {
                tried.insert(target.id)
                continue
            }
            world.enqueue(.place(.fireWatch, at: anchor))
            placed = anchor
            return
        }
    }

    static func isFireSeason(_ world: World) -> Bool {
        world.currentSeasonalEvent?.event.effect == .fire
    }

    /// The player's houses and workshops no fire watch, built or building,
    /// would answer, by the sim's own rule (reach and a road path), in
    /// entity order.
    static func uncovered(in world: World) -> [Building] {
        let watches = world.buildings.values.filter { $0.kind == .fireWatch && $0.owner == .player }
        return world.buildings.values
            .filter { $0.owner == .player && $0.state != .constructing && World.canIgnite($0.kind) }
            .sorted { $0.id.raw < $1.id.raw }
            .filter { building in !watches.contains { world.fireWatchCovers($0, building) } }
    }

    /// The first free plot, ring by ring out from `target`'s footprint, from
    /// which a watch would cover it by the sim's own rule.
    static func plot(near target: Building, in world: World) -> TileCoordinate? {
        let box = target.bounds
        for ring in 1 ... searchReach {
            for y in (box.minY - ring) ... (box.maxY + ring) {
                for x in (box.minX - ring) ... (box.maxX + ring) where max(box.minX - x, x - box.maxX, box.minY - y, y - box.maxY) == ring {
                    let tile = TileCoordinate(x: x, y: y)
                    let watch = Building(id: EntityID(raw: 0), kind: .fireWatch, anchor: tile, state: .operational)
                    guard world.canPlace(.fireWatch, at: tile) == .allowed, world.fireWatchCovers(watch, target) else { continue }
                    return tile
                }
            }
        }
        return nil
    }
}
