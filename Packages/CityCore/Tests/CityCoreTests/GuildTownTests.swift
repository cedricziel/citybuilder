import Foundation
import Testing
@testable import CityCore

/// Merchants need cloth to advance, so the Guild Town scenario (30 merchants,
/// 30 tools) takes the wool chain. The scripted town, which builds it on
/// demand, still wins it.
@Test("the Guild Town can still be won with the wool chain")
func guildTownStillWinnable() throws {
    var world = World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, scenario: .guildTown)
    let center = try #require(world.goodsBuffers(of: .player).first { $0.kind == .townCenter })
    var bot = PlayerBot(center: center, tradesAtMarket: true, firstSteps: PlayerBot.guideSteps, midGame: .careful)
    let sevenYears = 7 * Int(CalendarState.ticksPerYear)
    for tick in 1 ... sevenYears where !world.scenarioWon && !world.economy.gameOver {
        if tick.isMultiple(of: 50) { bot.takeTurn(&world) }
        world.tick()
    }
    #expect(world.scenarioWon)
    #expect(world.research.isResearched(.weaving))
    #expect(!world.economy.gameOver)
}
