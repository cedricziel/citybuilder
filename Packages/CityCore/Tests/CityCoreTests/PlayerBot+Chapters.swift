import Foundation
@testable import CityCore

/// The chapter kits (add-campaigns D10) the built-in chapters need on top
/// of the PlayerBot: `sea` researches Seafaring and builds a port and a
/// shipyard, `signature` builds the age's signature building.
struct ChapterKits {
    let kits: Set<String>

    /// Houses before a kit builds.
    static let seaHouses = 6
    static let signatureHouses = 10

    init(_ kits: [String]) {
        self.kits = Set(kits)
    }

    func takeTurn(_ world: inout World, bot: PlayerBot) {
        let houses = world.buildings.values.count { $0.owner == .player && $0.kind == .house }
        if kits.contains("sea"), world.research.current == nil, world.canChooseResearch(.seafaring) {
            world.enqueue(.chooseResearch(.seafaring))
        }
        var wanted: [BuildingKind] = []
        if kits.contains("sea"), houses >= Self.seaHouses { wanted += [.port, .shipyard] }
        if kits.contains("signature"), houses >= Self.signatureHouses {
            wanted.append(world.age.signature)
        }
        guard let kind = wanted.first(where: { kind in
            world.research.isAvailable(kind) && !world.buildings.values.contains { $0.owner == .player && $0.kind == kind }
        }) else { return }
        let stock = world.islandStockpile(at: bot.center.anchor, tileToIsland: world.tileToIslandMap())
        var plan = RivalTownPlan(world: world, owner: .player, center: bot.center.anchor)
        _ = bot.place(kind, in: &world, plan: &plan, stock: stock)
    }
}

/// How a bot game of a chapter ended.
struct ChapterRun {
    var wonTick: Int?
    var loss: LossReason?
    var world: World

    /// Ticks from the win to the first deadline, nil without a win or a deadline.
    var marginTicks: Int? {
        guard let wonTick, let year = world.loseConditions.compactMap({ state -> Int? in
            if case let .deadline(year) = state.condition { return year }
            return nil
        }).min() else { return nil }
        return (year - world.calendar.startYear) * Int(CalendarState.ticksPerYear) - wonTick
    }
}

extension World {
    /// Plays `chapter` with the bot its sweep names (add-campaigns D10),
    /// a turn every 50 ticks, until the chapter is won or lost, or for
    /// `maxYears`.
    static func chapterBotRun(
        _ chapter: Chapter, difficulty: Difficulty, culture: Culture = .northernEuropean, maxYears: Int = 12
    ) -> ChapterRun {
        var world = World.newGame(chapter: chapter, difficulty: difficulty, culture: culture)
        guard let center = world.goodsBuffers(of: .player).first(where: { $0.kind == .townCenter }) else {
            return ChapterRun(world: world)
        }
        let order: MidGameOrder? = switch chapter.sweep.order {
        case "careful": .careful
        case "naive": .naive
        default: nil
        }
        var bot = PlayerBot(
            center: center, tradesAtMarket: chapter.sweep.market,
            firstSteps: chapter.sweep.firstSteps ? PlayerBot.guideSteps : [], midGame: order
        )
        let kits = ChapterKits(chapter.sweep.kits)
        for tick in 1 ... maxYears * Int(CalendarState.ticksPerYear) {
            if tick.isMultiple(of: 50) {
                kits.takeTurn(&world, bot: bot)
                bot.takeTurn(&world)
            }
            world.tick()
            if world.scenarioWon { return ChapterRun(wonTick: tick, world: world) }
            if let loss = world.scenarioLoss { return ChapterRun(loss: loss, world: world) }
        }
        return ChapterRun(world: world)
    }
}
