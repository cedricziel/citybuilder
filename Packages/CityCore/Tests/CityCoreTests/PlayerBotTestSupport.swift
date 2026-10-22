@testable import CityCore

/// A scripted player for balance checks (`hard-bankruptcy-grace` D2):
/// the rival AI's opening, growth loop and town plan, the simple
/// threshold rules the rivals had in #47, and a $50 cushion. With
/// `tradesAtMarket` it buys the wood or planks a step lacks and sells
/// planks, then wood, above 12 units while its balance is below $150.
struct PlayerBot {
    let center: Building
    let tradesAtMarket: Bool
    private var script = RivalAIState()

    init(center: Building, tradesAtMarket: Bool) {
        self.center = center
        self.tradesAtMarket = tradesAtMarket
    }

    static let cushion: Int64 = 50
    static let sellBelowBalance: Int64 = 150
    static let keepOnSale = 12
    static let houseCap = 30

    mutating func takeTurn(_ world: inout World) {
        let stock = world.islandStockpile(at: center.anchor, tileToIsland: world.tileToIslandMap())
        if tradesAtMarket, world.economy.balance < Self.sellBelowBalance {
            for good in [Good.planks, .wood] {
                let units = min(stock[good, default: 0] - Self.keepOnSale, world.market.left(good, .sold))
                if units > 0 {
                    world.enqueue(.marketSell(center.id, good, units))
                    return
                }
            }
        }
        let town = Town(world: world)
        var plan = RivalTownPlan(world: world, owner: .player, center: center.anchor)
        let kinds = town.thresholdKinds(stock: stock, pastOpening: script.isPastOpening)
        for kind in kinds where !town.waiting || kind == .lumberjackHut {
            if place(kind, in: &world, plan: &plan, stock: stock) { return }
        }
        guard !town.waiting else { return }
        if RivalAI.scriptKind(at: script.scriptIndex) == .house, town.houses >= Self.houseCap {
            script.advance()
        }
        if place(RivalAI.scriptKind(at: script.scriptIndex), in: &world, plan: &plan, stock: stock) {
            script.advance()
        } else {
            script.waitTurns += 1
            if script.waitTurns >= RivalAI.waitLimit { script.advance() }
        }
    }

    /// Enqueues any purchase, the ring roads and the building; false
    /// when the bot must wait.
    private func place(
        _ kind: BuildingKind, in world: inout World, plan: inout RivalTownPlan, stock: [Good: Int]
    ) -> Bool {
        var buys: [Command] = []
        var price: Int64 = 0
        for (good, amount) in world.materialCost(of: kind, for: .player).sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let missing = amount - stock[good, default: 0]
            guard missing > 0 else { continue }
            guard tradesAtMarket, good == .wood || good == .planks, world.market.left(good, .bought) >= missing
            else { return false }
            buys.append(.marketBuy(center.id, good, missing))
            price += Int64(missing) * good.marketPrice(.bought)
        }
        let cost = BuildingCatalog.spec(for: kind).cost + Self.cushion + price
        guard world.economy.balance >= cost, let slot = plan.slot(for: kind) else { return false }
        guard world.economy.balance >= cost + BuildingCatalog.spec(for: .road).cost * Int64(slot.roads.count)
        else { return false }
        for command in buys + slot.roads.map({ .place(.road, at: $0) }) + [.place(kind, at: slot.anchor)] {
            world.enqueue(command)
        }
        return true
    }

    /// The player's buildings as the threshold rules see them.
    private struct Town {
        var counts: [BuildingKind: Int] = [:]
        var allHuts = 0
        var forestLeft = 0
        var waiting = false

        var houses: Int {
            counts[.house, default: 0]
        }

        init(world: World) {
            let hutFootprint = BuildingCatalog.spec(for: .lumberjackHut).footprint
            for building in world.buildings.values where building.owner == .player {
                if building.state == .constructing, building.constructionState == .waitingForMaterials { waiting = true }
                if building.kind == .lumberjackHut {
                    allHuts += 1
                    let forest = world.forestTiles(inCatchmentOf: building.anchor, footprint: hutFootprint)
                    forestLeft += forest
                    guard forest >= RivalAI.hutLowForest else { continue }
                }
                counts[building.kind, default: 0] += 1
            }
        }

        func thresholdKinds(stock: [Good: Int], pastOpening: Bool) -> [BuildingKind] {
            let huts = counts[.lumberjackHut, default: 0]
            var kinds: [BuildingKind] = []
            if stock[.food, default: 0] < 4, counts[.farm, default: 0] < (houses * 4 + 4) / 5 { kinds.append(.farm) }
            if pastOpening, stock[.planks, default: 0] < 6, counts[.sawmill, default: 0] < huts { kinds.append(.sawmill) }
            if stock[.wood, default: 0] < 4, huts < 1 + houses / 4 || forestLeft < RivalAI.hutMinForest {
                kinds.append(.lumberjackHut)
            }
            if counts[.forester, default: 0] < allHuts { kinds.append(.forester) }
            return kinds
        }
    }
}

extension World {
    /// Plays `ticks` ticks of a new game with `bot` taking a turn every
    /// 50 ticks; true when the game ends in bankruptcy.
    static func botGoesBankrupt(
        layout: WorldLayout, seed: UInt64, difficulty: Difficulty, tradesAtMarket: Bool, ticks: Int
    ) -> Bool {
        var world = World.newGame(layout: layout, seed: seed, difficulty: difficulty)
        world.calendar = CalendarState(startYear: 1200, isActive: true)
        guard let center = world.goodsBuffers(of: .player).first(where: { $0.kind == .townCenter }) else { return false }
        var bot = PlayerBot(center: center, tradesAtMarket: tradesAtMarket)
        for tick in 1 ... ticks where !world.economy.gameOver {
            if tick.isMultiple(of: 50) { bot.takeTurn(&world) }
            world.tick()
        }
        return world.economy.gameOver
    }
}
