import Foundation
@testable import CityCore

/// The PlayerBot's events kit (`add-event-counterplay` D12). One answer a
/// turn, while the event is warned or under way:
/// - fire: a fire watch by the first house or workshop no watch covers, so
///   every 8-tile cluster ends up with one;
/// - blight: a granary when the town has none;
/// - fever: a physician over the marked district and a herb garden, and
///   herbs from the market while the physicians hold fewer than 2;
/// - festival: accepts the town's orders once the stores hold half of each
///   good, and sends each once it is stocked.
struct EventsKit {
    /// What a building costs on top of its price before the kit builds it.
    static let cushion: Int64 = 50
    /// How far from its target the kit looks for a plot, in tiles.
    static let searchReach = 4
    /// How far from the town center the kit looks for a granary or herb
    /// garden plot, ring by ring: a grown town has no room right beside it,
    /// and a crowded one may have none within 12.
    static let townReach = 20
    /// Herbs the kit buys at a time, and the physicians' stock it buys below.
    static let herbsBought = 4
    static let herbsLow = 2

    /// Buildings the kit placed that stand, by kind: counted once the
    /// placement succeeded, at the kit's next turn.
    private(set) var built: [BuildingKind: Int] = [:]
    private(set) var festivalsAccepted = 0
    private(set) var herbsBuys = 0
    /// Where the last placement went, until the kit sees whether it stood.
    private var placed: (anchor: TileCoordinate, kind: BuildingKind)?
    /// Buildings with no plot a watch would cover from, not tried again.
    private var tried: Set<EntityID> = []

    var watchesBuilt: Int {
        built[.fireWatch, default: 0]
    }

    mutating func takeTurn(_ world: inout World) {
        if let (anchor, kind) = placed {
            placed = nil
            if let id = world.occupiedTiles[anchor], world.buildings[id]?.kind == kind { built[kind, default: 0] += 1 }
        }
        switch world.currentSeasonalEvent?.event.effect {
        case .fire?: answerFire(&world)
        case .blight?: answerBlight(&world)
        case .fever?: answerFever(&world)
        case .festival?: answerFestival(&world)
        case nil: break
        }
    }

    // MARK: - Fire

    private mutating func answerFire(_ world: inout World) {
        guard Self.canAfford(.fireWatch, world) else { return }
        for target in Self.uncovered(in: world) where !tried.contains(target.id) {
            let covers = { (tile: TileCoordinate) in
                world.fireWatchCovers(Building(id: EntityID(raw: 0), kind: .fireWatch, anchor: tile, state: .operational), target)
            }
            guard let anchor = Self.plot(for: .fireWatch, near: target, in: world, where: covers) else {
                tried.insert(target.id)
                continue
            }
            place(.fireWatch, at: anchor, in: &world)
            return
        }
    }

    /// The player's houses and workshops no fire watch, built or building,
    /// would answer, by the sim's own rule (reach and a road path), in
    /// entity order. Crop fields lie spread out and burn alone, so the kit,
    /// like a careful player, leaves them; once these are covered it builds
    /// no more watches.
    static func uncovered(in world: World) -> [Building] {
        let watches = world.buildings.values.filter { $0.kind == .fireWatch && $0.owner == .player }
        return world.buildings.values
            .filter { $0.owner == .player && $0.state != .constructing && World.canIgnite($0.kind) && !$0.kind.isCrop }
            .sorted { $0.id.raw < $1.id.raw }
            .filter { building in !watches.contains { world.fireWatchCovers($0, building) } }
    }

    // MARK: - Blight

    private mutating func answerBlight(_ world: inout World) {
        guard !Self.owns(.granary, world), Self.canAfford(.granary, world), let center = Self.townCenter(world),
              let anchor = Self.plot(for: .granary, near: center, in: world, reach: Self.townReach)
        else { return }
        place(.granary, at: anchor, in: &world)
    }

    // MARK: - Fever

    private mutating func answerFever(_ world: inout World) {
        if let district = Self.districtHouse(world), !Self.isCovered(district, world) {
            let inReach = { (tile: TileCoordinate) in
                World.footprintDistance(Building(id: EntityID(raw: 0), kind: .physician, anchor: tile), district) <= World.physicianReach
            }
            guard Self.canAfford(.physician, world),
                  let anchor = Self.plot(for: .physician, near: district, in: world, where: inReach)
            else { return }
            place(.physician, at: anchor, in: &world)
            return
        }
        if let center = Self.townCenter(world), Self.herbsLow(world) {
            world.enqueue(.marketBuy(center.id, .herbs, Self.herbsBought))
            herbsBuys += 1
        }
        guard !Self.owns(.herbGarden, world), Self.canAfford(.herbGarden, world), let center = Self.townCenter(world),
              let anchor = Self.plot(for: .herbGarden, near: center, in: world, reach: Self.townReach)
        else { return }
        place(.herbGarden, at: anchor, in: &world)
    }

    /// The house the fever's district is marked around.
    static func districtHouse(_ world: World) -> Building? {
        guard let area = world.seasonalEvents.marked else { return nil }
        return world.buildings.values.first { $0.kind == .house && $0.bounds == area.around }
    }

    /// A player physician, built or building, within reach of `house`.
    static func isCovered(_ house: Building, _ world: World) -> Bool {
        world.buildings.values.contains {
            $0.kind == .physician && $0.owner == .player && World.footprintDistance($0, house) <= World.physicianReach
        }
    }

    /// The operational physicians hold fewer than `herbsLow` herbs between
    /// them, and the stores hold none to bring them.
    static func herbsLow(_ world: World) -> Bool {
        let physicians = world.buildings.values.filter { $0.kind == .physician && $0.owner == .player && $0.state == .operational }
        guard !physicians.isEmpty else { return false }
        let held = physicians.reduce(0) { $0 + (world.stockpiles[$1.id]?.quantity(of: .herbs) ?? 0) }
        let stored = world.goodsBuffers(of: .player).reduce(0) { $0 + (world.stockpiles[$1.id]?.quantity(of: .herbs) ?? 0) }
        return held < herbsLow && stored == 0
    }

    // MARK: - Festival

    private mutating func answerFestival(_ world: inout World) {
        let town = world.orders.orders.filter { $0.issuer == .town }
        let offered = town.filter { $0.state == .offered }
        if !offered.isEmpty, offered.allSatisfy({ world.orderAvailable(for: $0.id) * 2 >= $0.quantity }) {
            for order in offered {
                world.enqueue(.acceptOrder(order.id))
            }
            festivalsAccepted += 1
        }
        for order in town where order.state == .accepted {
            if case .ready = world.orderDispatch(for: order.id) {
                world.enqueue(.dispatchOrder(order.id))
            }
        }
    }

    // MARK: - Placing

    private mutating func place(_ kind: BuildingKind, at anchor: TileCoordinate, in world: inout World) {
        world.enqueue(.place(kind, at: anchor))
        placed = (anchor, kind)
    }

    static func canAfford(_ kind: BuildingKind, _ world: World) -> Bool {
        world.economy.balance >= BuildingCatalog.spec(for: kind).cost + cushion
    }

    static func owns(_ kind: BuildingKind, _ world: World) -> Bool {
        world.buildings.values.contains { $0.kind == kind && $0.owner == .player }
    }

    static func townCenter(_ world: World) -> Building? {
        world.goodsBuffers(of: .player).first { $0.kind == .townCenter }
    }

    /// The first free plot, ring by ring out from `target`'s footprint, that
    /// passes `accepts`. Anything but a fire watch also needs a road beside
    /// it, for its carriers.
    static func plot(
        for kind: BuildingKind, near target: Building, in world: World, reach: Int = searchReach,
        where accepts: (TileCoordinate) -> Bool = { _ in true }
    ) -> TileCoordinate? {
        let box = target.bounds
        let footprint = BuildingCatalog.spec(for: kind).footprint
        for ring in 1 ... reach {
            for y in (box.minY - ring) ... (box.maxY + ring) {
                for x in (box.minX - ring) ... (box.maxX + ring) where max(box.minX - x, x - box.maxX, box.minY - y, y - box.maxY) == ring {
                    let tile = TileCoordinate(x: x, y: y)
                    guard world.canPlace(kind, at: tile) == .allowed, accepts(tile),
                          kind == .fireWatch || world.anyAdjacentRoad(anchor: tile, footprint: footprint) != nil
                    else { continue }
                    return tile
                }
            }
        }
        return nil
    }
}
