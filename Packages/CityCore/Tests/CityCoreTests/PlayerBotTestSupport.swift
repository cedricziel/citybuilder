@testable import CityCore

/// A scripted player for balance checks (`hard-bankruptcy-grace` D2):
/// the rival AI's opening, growth loop and town plan, the simple
/// threshold rules the rivals had in #47, and a $50 cushion. With
/// `tradesAtMarket` it buys the wood or planks a step lacks and sells
/// planks, then wood, above 12 units while its balance is below $150.
struct PlayerBot {
    let center: Building
    let tradesAtMarket: Bool
    /// Buildings placed in this order before anything else, one per
    /// entry, waiting until each fits (`first-hour-guidance` D4).
    let firstSteps: [BuildingKind]
    /// Researches and builds the bread, tools and luxury chains once the
    /// town has `midGameHouses` houses (#186, `PlayerBot+MidGame.swift`).
    let midGame: MidGameOrder?
    private var script = RivalAIState()

    init(center: Building, tradesAtMarket: Bool, firstSteps: [BuildingKind] = [], midGame: MidGameOrder? = nil) {
        self.center = center
        self.tradesAtMarket = tradesAtMarket
        self.firstSteps = firstSteps
        self.midGame = midGame
    }

    /// The first-hour guide's order: food first so houses fill, then the
    /// planks a house needs, then houses for tax.
    static let guideSteps: [BuildingKind] = [.farm, .lumberjackHut, .sawmill, .house, .house, .house]

    static let cushion: Int64 = 50
    static let sellBelowBalance: Int64 = 150
    static let keepOnSale = 12
    static let houseCap = 30

    mutating func takeTurn(_ world: inout World) {
        let stock = world.islandStockpile(at: center.anchor, tileToIsland: world.tileToIslandMap())
        if sellAtMarket(in: &world, stock: stock) { return }
        if midGame != nil { chooseResearch(in: &world, stock: stock) }
        let town = Town(world: world)
        var plan = RivalTownPlan(world: world, owner: .player, center: center.anchor)
        if followIdleGoodHint(in: &world, plan: &plan, stock: stock) { return }
        // Like a rival, the bot builds a marketplace once its next house
        // would fall outside every hub's reach, a guided house too.
        let needsMarketplace = plan.needsMarketplace()
        if let next = nextFirstStep(in: world) {
            // A marketplace it can't place yet doesn't hold up the guided house.
            if next == .house, needsMarketplace, place(.marketplace, in: &world, plan: &plan, stock: stock) { return }
            _ = place(next, in: &world, plan: &plan, stock: stock)
            return
        }
        let kinds = (needsMarketplace ? [.marketplace] : [])
            + town.thresholdKinds(stock: stock, pastOpening: script.isPastOpening)
        for kind in kinds where !town.waiting || kind == .lumberjackHut {
            if place(kind, in: &world, plan: &plan, stock: stock) { return }
        }
        guard !town.waiting else { return }
        let chain = missingMidGameKinds(in: world, town: town) + missingWoolChainKinds(in: world, town: town, stock: stock)
        for kind in chain where place(kind, in: &world, plan: &plan, stock: stock) {
            return
        }
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

    /// While trading: sells planks, then wood, above `keepOnSale` when
    /// cash is short, which ends the turn; with the careful mid-game kit
    /// also sells raw surplus every turn.
    private func sellAtMarket(in world: inout World, stock: [Good: Int]) -> Bool {
        guard tradesAtMarket else { return false }
        func surplus(_ good: Good) -> Int {
            min(stock[good, default: 0] - Self.keepOnSale, world.market.left(good, .sold))
        }
        let shortOfCash = world.economy.balance < Self.sellBelowBalance
        if shortOfCash, let good = [Good.planks, .wood].first(where: { surplus($0) > 0 }) {
            world.enqueue(.marketSell(center.id, good, surplus(good)))
            return true
        }
        if midGame == .careful {
            for good in Self.rawSurplus(world.culture) where surplus(good) > 0 {
                world.enqueue(.marketSell(center.id, good, surplus(good)))
            }
        }
        return false
    }

    /// The first entry of `firstSteps` the player's buildings don't
    /// cover yet, counting every kind in order.
    private func nextFirstStep(in world: World) -> BuildingKind? {
        var owned: [BuildingKind: Int] = [:]
        for building in world.buildings.values where building.owner == .player {
            owned[building.kind, default: 0] += 1
        }
        for kind in firstSteps {
            guard owned[kind, default: 0] > 0 else { return kind }
            owned[kind, default: 0] -= 1
        }
        return nil
    }

    /// Enqueues any purchase, the ring roads and the building; false
    /// when the bot must wait.
    func place(
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
        guard world.economy.balance >= cost, let slot = plan.slot(for: kind) ?? roadsideMineSlot(kind, in: world) else { return false }
        guard world.economy.balance >= cost + BuildingCatalog.spec(for: .road).cost * Int64(slot.roads.count)
        else { return false }
        for command in buys + slot.roads.map({ .place(.road, at: $0) }) + [.place(kind, at: slot.anchor)] {
            world.enqueue(command)
        }
        return true
    }

    /// The player's buildings as the threshold rules see them.
    struct Town {
        var counts: [BuildingKind: Int] = [:]
        var allHuts = 0
        var forestLeft = 0
        var waiting = false

        var houses: Int {
            counts[.house, default: 0]
        }

        init(world: World) {
            for building in world.buildings.values where building.owner == .player {
                if building.state == .constructing, building.constructionState == .waitingForMaterials { waiting = true }
                if building.kind == .lumberjackHut {
                    allHuts += 1
                    let forest = world.forestTiles(inCatchmentOf: building.kind, at: building.anchor)
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
    /// Plays `ticks` ticks of a new game with the bot taking a turn every
    /// 50 ticks, stopping early at bankruptcy; returns the final world.
    static func botGame(
        layout: WorldLayout, seed: UInt64, difficulty: Difficulty, tradesAtMarket: Bool,
        firstSteps: [BuildingKind] = [], orders: Bool = false, events: BotEvents = .off, ticks: Int
    ) -> World {
        var world = World.newGame(layout: layout, seed: seed, difficulty: difficulty, seasonalEvents: events.isOn)
        world.calendar = CalendarState(startYear: 1200, isActive: true)
        world.seasonalEvents.schedule = events.schedule
        guard let center = world.goodsBuffers(of: .player).first(where: { $0.kind == .townCenter }) else { return world }
        var bot = PlayerBot(center: center, tradesAtMarket: tradesAtMarket, firstSteps: firstSteps)
        var kit = orders ? OrdersKit() : nil
        var eventsKit = events.answers ? EventsKit() : nil
        for tick in 1 ... ticks where !world.economy.gameOver {
            if tick.isMultiple(of: 50) {
                eventsKit?.takeTurn(&world)
                bot.takeTurn(&world)
                kit?.takeTurn(&world)
            }
            world.tick()
        }
        return world
    }
}

/// Seasonal events in a bot game: off, drawn, or with a forced schedule,
/// and whether the events kit answers them (`add-event-counterplay` D12).
struct BotEvents {
    var isOn = false
    var schedule: [ScheduledSeasonalEvent] = []
    var answers = false

    static let off = BotEvents()

    /// A sweep's event arms from its env value: "1" runs each game with
    /// events off and on, "only" with events on alone, anything else off.
    static func arms(from value: String?) -> [Bool] {
        switch value {
        case "1": [false, true]
        case "only": [true]
        default: [false]
        }
    }

    static func drawn(answered: Bool) -> BotEvents {
        BotEvents(isOn: true, answers: answered)
    }

    /// The forced first-hour variant: one `event` in `onset` 1202.
    static func forced(_ event: SeasonalEvent, _ onset: Season, answered: Bool) -> BotEvents {
        BotEvents(isOn: true, schedule: [ScheduledSeasonalEvent(year: 1202, event: event, onset: onset)], answers: answered)
    }
}
