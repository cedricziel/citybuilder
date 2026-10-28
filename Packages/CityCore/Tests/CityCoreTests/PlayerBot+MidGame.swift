import Foundation
@testable import CityCore

/// The PlayerBot's opt-in mid-game kit (#186): research toward the tools,
/// bread and luxury chains and the Renaissance, then one building of
/// each chain per 12 houses. The wool chain is the exception: it is built
/// on demand, from the houses that want cloth (#239).
extension PlayerBot {
    /// Houses before the kit starts building.
    static let midGameHouses = 6

    /// Inhabited citizens houses the bot builds cloth for ahead of their promotion.
    static let readyHouses = 2

    /// Cloth in the stores at which the bot stops building the wool chain.
    static let clothSurplus = 20

    /// Research in this order, each once it can be chosen.
    static let midGameResearch: [Tech] = [.milling, .mining, .metallurgy, .cultivation, .weaving, .printingPress]

    /// Starts the next tech of `midGameResearch` while nothing is being
    /// researched; Weaving waits until a house wants cloth.
    func chooseResearch(in world: inout World, stock: [Good: Int]) {
        guard world.research.current == nil else { return }
        let wantsCloth = clothDemand(in: world, stock: stock) > 0
        guard let tech = Self.midGameResearch.first(where: {
            world.canChooseResearch($0) && ($0 != .weaving || wantsCloth)
        })
        else { return }
        world.enqueue(.chooseResearch(tech))
    }

    /// Houses that want cloth (#239): merchant houses, and the next
    /// `readyHouses` inhabited citizens houses once bread and tools are in
    /// the stores, so the cloth is there when they fill up and lack only
    /// it to become merchants. Counting every citizens house would build
    /// weavers for houses that are not about to move up.
    func clothDemand(in world: World, stock: [Good: Int]) -> Int {
        let chainsRun = stock[.bread, default: 0] > 0 && stock[.tools, default: 0] > 0
        var merchants = 0
        var ready = 0
        for building in world.buildings.values where building.owner == .player && building.kind == .house {
            guard let house = world.populations[building.id] else { continue }
            if house.tier == .merchants {
                merchants += 1
            } else if chainsRun, house.tier == .citizens, house.population > 0 {
                ready += 1
            }
        }
        return merchants + min(ready, Self.readyHouses)
    }

    /// The wool chain buildings the town lacks for its cloth demand: one
    /// weaver per two houses and two sheep farms per
    /// weaver, as many as the demand wants, and none while `clothSurplus` cloth already waits
    /// in the stores. `.naive` builds the sheep farms first, `.careful` the
    /// weaver first.
    func missingWoolChainKinds(in world: World, town: Town, stock: [Good: Int]) -> [BuildingKind] {
        guard midGame != nil, stock[.cloth, default: 0] < Self.clothSurplus else { return [] }
        let weavers = (clothDemand(in: world, stock: stock) + 1) / 2
        let wanted: [(kind: BuildingKind, count: Int)] = midGame == .careful
            ? [(.weaver, weavers), (.sheepFarm, 2 * weavers)]
            : [(.sheepFarm, 2 * weavers), (.weaver, weavers)]
        return wanted.compactMap { kind, count in
            town.counts[kind, default: 0] < count && world.research.isAvailable(kind) ? kind : nil
        }
    }

    /// The chain buildings the town lacks, in build order, each unlocked,
    /// one per two houses past `midGameHouses` so the town keeps growing.
    /// Per 12 houses: two grain farms, a mill and a bakery; a mine, a
    /// charcoal burner, a smelter and a toolsmith; two of the culture's
    /// luxury gardens and a producer; and one library in all. The mill is
    /// a quern house until milling unlocks the windmill.
    ///
    /// `.naive` builds each chain from its raw end, as the bread and tools
    /// read in the palette. `.careful` builds consumers before producers,
    /// adds a warehouse,
    /// and sells raw surplus at the market when it trades there.
    func missingMidGameKinds(in world: World, town: Town) -> [BuildingKind] {
        guard let order = midGame, town.houses >= Self.midGameHouses else { return [] }
        let chainBuilt = Self.chainKinds(world.culture).reduce(0) { $0 + town.counts[$1, default: 0] }
        guard town.houses >= Self.midGameHouses + 2 * chainBuilt else { return [] }
        let sets = 1 + town.houses / 12
        let mill: BuildingKind = world.research.isAvailable(.windmill) ? .windmill : .quernHouse
        let luxury = world.culture.luxuryChain
        // Each entry is (kinds, per set); a set is completed across every
        // chain before the next set starts.
        let perSet: [(kinds: [BuildingKind], count: Int)] = switch order {
        case .naive, .naiveFollowingHints: [
                ([.library], 0),
                ([.grainFarm], 2), ([.quernHouse, .windmill], 1), ([.bakery], 1),
                ([.mine], 1), ([.charcoalBurner], 1), ([.smelter], 1), ([.toolsmith], 1),
                ([luxury.garden], 2), ([luxury.producer], 1)
            ]
        case .careful: [
                ([.library], 0), ([.warehouse], 0),
                ([.quernHouse, .windmill], 1), ([.bakery], 1), ([.grainFarm], 2),
                ([.toolsmith], 1), ([.smelter], 1), ([.mine], 1), ([.charcoalBurner], 1),
                ([luxury.producer], 1), ([luxury.garden], 2)
            ]
        }
        var missing: [BuildingKind] = []
        for set in 1 ... sets {
            for (kinds, count) in perSet {
                // Library and warehouse: one in all.
                let target = count == 0 ? 1 : count * set
                let owned = kinds.reduce(0) { $0 + town.counts[$1, default: 0] }
                let kind = kinds.contains(.windmill) ? mill : kinds[0]
                if owned < target, world.research.isAvailable(kind), !missing.contains(kind) { missing.append(kind) }
            }
        }
        return missing
    }

    /// A mine site the town plan's block corners miss, such as the
    /// starter mine site beside the town center: the nearest anchor
    /// within `mineSearchRadius` tiles where a mine may stand and a road
    /// touches, or a short road would join it to the network.
    func roadsideMineSlot(_ kind: BuildingKind, in world: World) -> (roads: [TileCoordinate], anchor: TileCoordinate)? {
        guard kind == .mine else { return nil }
        let footprint = BuildingCatalog.spec(for: .mine).footprint
        let tileToIsland = world.tileToIslandMap()
        var near: [(dx: Int, dy: Int)] = []
        for dy in -Self.mineSearchRadius ... Self.mineSearchRadius {
            for dx in -Self.mineSearchRadius ... Self.mineSearchRadius {
                near.append((dx, dy))
            }
        }
        near.sort { $0.dx * $0.dx + $0.dy * $0.dy < $1.dx * $1.dx + $1.dy * $1.dy }
        for (dx, dy) in near {
            let anchor = TileCoordinate(x: center.anchor.x + dx, y: center.anchor.y + dy)
            guard world.siteRejection(.mine, at: anchor, for: .player, tileToIsland: tileToIsland) == nil else { continue }
            if world.anyAdjacentRoad(anchor: anchor, footprint: footprint) != nil { return ([], anchor) }
            if let link = Self.roadLink(to: anchor, footprint: footprint, in: world, tileToIsland: tileToIsland) {
                return (link, anchor)
            }
        }
        return nil
    }

    static let mineSearchRadius = 30

    /// The shortest run of free tiles, at most `maxRoadLink` long, that
    /// joins the footprint to the road network, found breadth-first from
    /// the footprint's sides; nil when none is that short.
    static func roadLink(
        to anchor: TileCoordinate, footprint: Footprint, in world: World, tileToIsland: [TileCoordinate: IslandID]
    ) -> [TileCoordinate]? {
        let tiles = Set(footprint.tiles(anchor: anchor))
        func neighbours(_ tile: TileCoordinate) -> [TileCoordinate] {
            [(1, 0), (-1, 0), (0, 1), (0, -1)].map { TileCoordinate(x: tile.x + $0.0, y: tile.y + $0.1) }
        }
        func isFree(_ tile: TileCoordinate) -> Bool {
            world.siteRejection(.road, at: tile, for: .player, tileToIsland: tileToIsland) == nil
        }
        var parent: [TileCoordinate: TileCoordinate] = [:]
        var depth: [TileCoordinate: Int] = [:]
        var queue: [TileCoordinate] = []
        for tile in tiles.sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) {
            for side in neighbours(tile) where !tiles.contains(side) && depth[side] == nil && isFree(side) {
                depth[side] = 1
                queue.append(side)
            }
        }
        var cursor = 0
        while cursor < queue.count {
            let tile = queue[cursor]
            cursor += 1
            if neighbours(tile).contains(where: { world.roadGraph.isConnected($0) }) {
                var path = [tile]
                var step = tile
                while let previous = parent[step] {
                    path.append(previous)
                    step = previous
                }
                return path
            }
            guard let tileDepth = depth[tile], tileDepth < maxRoadLink else { continue }
            for next in neighbours(tile) where !tiles.contains(next) && depth[next] == nil && isFree(next) {
                depth[next] = tileDepth + 1
                parent[next] = tile
                queue.append(next)
            }
        }
        return nil
    }

    static let maxRoadLink = 30

    /// Acts on the idle-good hint: places the first user of the first
    /// idle good. True when it placed one.
    func followIdleGoodHint(in world: inout World, plan: inout RivalTownPlan, stock: [Good: Int]) -> Bool {
        guard midGame == .naiveFollowingHints else { return false }
        for idle in world.idleGoods(of: .player) where place(idle.users[0], in: &world, plan: &plan, stock: stock) {
            return true
        }
        return false
    }

    /// The buildings the throttle counts as the kit's.
    static func chainKinds(_ culture: Culture) -> [BuildingKind] {
        [
            .library,
            .warehouse,
            .grainFarm,
            .quernHouse,
            .windmill,
            .bakery,
            .mine,
            .charcoalBurner,
            .smelter,
            .toolsmith,
            culture.luxuryChain.garden,
            culture.luxuryChain.producer
        ]
    }

    /// Raw goods, and the cloth, the careful kit sells above `keepOnSale` units.
    static func rawSurplus(_ culture: Culture) -> [Good] {
        [.grain, .ore, .charcoal, .wool, .cloth, culture.luxuryChain.raw]
    }
}

/// How the mid-game kit orders each chain (#186).
enum MidGameOrder {
    case naive
    /// The naive order, but acting on the idle-good hint: it first builds
    /// a user of a good piling up (`keep-the-town-supplied` D4).
    case naiveFollowingHints
    case careful
}

/// One measured setup of the mid-game sweep.
struct MidGameArm {
    let layout: WorldLayout
    let difficulty: Difficulty
    let tradesAtMarket: Bool
    let order: MidGameOrder
}

/// When a bot game first reached each mid-game milestone, in ticks.
struct MidGameMilestones {
    var firstMerchant: Int?
    var twentyMerchants: Int?
    var renaissance: Int?
    /// With PACING_RETENTION=1: merchants at the end of year 10 and the
    /// share of years 8–10's bot turns with 20 or more merchants (#223).
    var merchantsAtTen: Int?
    var heldShare: Double?
    var bankruptAt: Int?
    /// Goods the idle-good hint would have named, in first-seen order.
    var hinted: [Good] = []

    static func years(_ tick: Int?) -> String {
        tick.map { String(format: "%.1f", Double($0) / Double(CalendarState.ticksPerYear)) } ?? "-"
    }
}

extension MidGameMilestones {
    /// Notes this bot turn's milestones; true when the run can stop. With
    /// `retention` the run goes on to year 10 and records the merchants
    /// there and the share of years 8–10's turns with 20 or more (#223).
    mutating func note(_ world: World, tick: Int, retention: Bool, late: inout (turns: Int, held: Int)) -> Bool {
        for idle in world.idleGoods(of: .player) where !hinted.contains(idle.good) {
            hinted.append(idle.good)
        }
        let merchants = world.residents(atLeast: .merchants)
        if firstMerchant == nil, merchants > 0 { firstMerchant = tick }
        if twentyMerchants == nil, merchants >= 20 { twentyMerchants = tick }
        if renaissance == nil, world.age >= .renaissance { renaissance = tick }
        guard retention else { return renaissance != nil }
        let year = Int(CalendarState.ticksPerYear)
        if tick > 8 * year {
            late.turns += 1
            if merchants >= 20 { late.held += 1 }
        }
        guard tick >= 10 * year else { return false }
        merchantsAtTen = merchants
        heldShare = Double(late.held) / Double(max(late.turns, 1))
        return true
    }
}

extension World {
    /// Plays a guided start with the mid-game kit for `ticks` ticks and
    /// records the milestones, checked every bot turn.
    static func midGameRun(_ arm: MidGameArm, seed: UInt64, ticks: Int) -> MidGameMilestones {
        var world = World.newGame(layout: arm.layout, seed: seed, difficulty: arm.difficulty)
        world.calendar = CalendarState(startYear: 1200, isActive: true)
        var milestones = MidGameMilestones()
        let retention = ProcessInfo.processInfo.environment["PACING_RETENTION"] == "1"
        var late = (turns: 0, held: 0)
        guard let center = world.goodsBuffers(of: .player).first(where: { $0.kind == .townCenter }) else { return milestones }
        var bot = PlayerBot(center: center, tradesAtMarket: arm.tradesAtMarket, firstSteps: PlayerBot.guideSteps, midGame: arm.order)
        for tick in 1 ... ticks {
            if tick.isMultiple(of: 50) {
                bot.takeTurn(&world)
                if milestones.note(world, tick: tick, retention: retention, late: &late) { break }
            }
            world.tick()
            if world.economy.gameOver {
                milestones.bankruptAt = tick
                break
            }
        }
        return milestones
    }
}
