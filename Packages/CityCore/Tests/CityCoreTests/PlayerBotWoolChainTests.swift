import Testing
@testable import CityCore

// The PlayerBot's demand-based wool chain (#239, openspec/changes/add-wool-cloth-chain D4).

private let breadAndTools: [Good: Int] = [.bread: 4, .tools: 2]

private struct WoolTown {
    var world: World
    let bot: PlayerBot

    init(order: MidGameOrder, houses: [(HouseTier, UInt32)], built: [BuildingKind] = []) throws {
        world = SignatureFixture.grass()
        world.research = ResearchState(researched: Tech.allCases.filter { $0 != .printingPress })
        for (index, (tier, residents)) in houses.enumerated() {
            let house = SignatureFixture.inject(.house, at: TileCoordinate(x: 2 * index, y: 0), in: &world)
            var population = HousePopulation()
            population.tier = tier
            population.population = residents
            world.populations[house] = population
        }
        for (index, kind) in built.enumerated() {
            SignatureFixture.inject(kind, at: TileCoordinate(x: 2 * index, y: 6), in: &world)
        }
        let center = SignatureFixture.inject(.townCenter, at: TileCoordinate(x: 20, y: 20), in: &world)
        bot = try PlayerBot(center: #require(world.buildings[center]), tradesAtMarket: false, midGame: order)
    }

    func missing(stock: [Good: Int] = breadAndTools) -> [BuildingKind] {
        bot.missingWoolChainKinds(in: world, town: PlayerBot.Town(world: world), stock: stock)
    }
}

@Test("the bot wants no cloth without merchants or merchants in waiting")
func botWantsNoClothWithoutDemand() throws {
    let peasants = try WoolTown(order: .careful, houses: [(.peasants, 4), (.citizens, 3)])
    #expect(peasants.bot.clothDemand(in: peasants.world, stock: breadAndTools) == 0)
    #expect(peasants.missing().isEmpty)
}

@Test("a full citizens house with bread and tools in reach wants cloth")
func botCountsFullCitizensHouses() throws {
    let town = try WoolTown(order: .careful, houses: [(.citizens, 6), (.citizens, 5)])
    #expect(town.bot.clothDemand(in: town.world, stock: breadAndTools) == 1)
    #expect(town.bot.clothDemand(in: town.world, stock: [.bread: 4]) == 0)
    #expect(town.bot.clothDemand(in: town.world, stock: [.tools: 2]) == 0)
}

@Test("only the next few full citizens houses count ahead of their promotion")
func botCapsTheReadyHouses() throws {
    let town = try WoolTown(order: .careful, houses: Array(repeating: (.citizens, 6), count: 5) + [(.merchants, 8)])
    #expect(town.bot.clothDemand(in: town.world, stock: breadAndTools) == 1 + PlayerBot.readyHouses)
}

@Test("merchant houses want cloth whatever the stock")
func botCountsMerchantHouses() throws {
    let town = try WoolTown(order: .careful, houses: [(.merchants, 8), (.merchants, 2)])
    #expect(town.bot.clothDemand(in: town.world, stock: [:]) == 2)
}

@Test("the bot ignores rival houses")
func botIgnoresRivalHouses() throws {
    var town = try WoolTown(order: .careful, houses: [])
    let house = SignatureFixture.inject(.house, at: TileCoordinate(x: 0, y: 0), in: &town.world, owner: .rival(1))
    var population = HousePopulation()
    population.tier = .merchants
    population.population = 8
    town.world.populations[house] = population
    #expect(town.bot.clothDemand(in: town.world, stock: breadAndTools) == 0)
}

@Test("the careful bot builds the weaver first, then two sheep farms per weaver")
func carefulBotBuildsTheWeaverFirst() throws {
    var town = try WoolTown(order: .careful, houses: [(.merchants, 8), (.merchants, 8), (.merchants, 8)])
    #expect(town.missing() == [.weaver, .sheepFarm])
    town = try WoolTown(order: .careful, houses: [(.merchants, 8), (.merchants, 8), (.merchants, 8)], built: [.weaver, .weaver])
    #expect(town.missing() == [.sheepFarm])
    town = try WoolTown(
        order: .careful, houses: [(.merchants, 8), (.merchants, 8), (.merchants, 8)],
        built: [.weaver, .weaver, .sheepFarm, .sheepFarm, .sheepFarm, .sheepFarm]
    )
    #expect(town.missing().isEmpty)
}

@Test("the naive bot builds the sheep farms first")
func naiveBotBuildsTheSheepFarmsFirst() throws {
    let town = try WoolTown(order: .naive, houses: [(.merchants, 8)])
    #expect(town.missing() == [.sheepFarm, .weaver])
}

@Test("the bot builds nothing without the mid-game kit or before Weaving")
func botWaitsForTheKitAndForWeaving() throws {
    var town = try WoolTown(order: .careful, houses: [(.merchants, 8)])
    let plain = PlayerBot(center: town.bot.center, tradesAtMarket: false)
    #expect(plain.missingWoolChainKinds(in: town.world, town: PlayerBot.Town(world: town.world), stock: breadAndTools).isEmpty)
    town.world.research = ResearchState(researched: [.scholarship])
    #expect(town.missing().isEmpty)
}

@Test("the bot researches Weaving once a house wants cloth, not before")
func botResearchesWeavingOnDemand() throws {
    let idle = try WoolTown(order: .careful, houses: [(.citizens, 3)])
    var world = idle.world
    world.research = ResearchState(researched: Tech.allCases.filter { ![.weaving, .printingPress].contains($0) })
    idle.bot.chooseResearch(in: &world, stock: breadAndTools)
    world.tick()
    #expect(world.research.current == nil)

    let wanting = try WoolTown(order: .careful, houses: [(.merchants, 8)])
    var wantingWorld = wanting.world
    wantingWorld.research = world.research
    wanting.bot.chooseResearch(in: &wantingWorld, stock: breadAndTools)
    wantingWorld.tick()
    #expect(wantingWorld.research.current == .weaving)
}

@Test("the bot builds at most three weavers")
func botCapsTheWeavers() throws {
    let merchants = Array(repeating: (HouseTier.merchants, UInt32(8)), count: 12)
    let town = try WoolTown(order: .careful, houses: merchants, built: Array(repeating: .weaver, count: PlayerBot.maxWeavers))
    #expect(town.missing() == [.sheepFarm])
}

@Test("the bot builds no more of the wool chain while cloth piles up")
func botStopsWhenClothPilesUp() throws {
    let town = try WoolTown(order: .careful, houses: [(.merchants, 8), (.merchants, 8)])
    #expect(town.missing(stock: [.cloth: PlayerBot.clothSurplus - 1]) == [.weaver, .sheepFarm])
    #expect(town.missing(stock: [.cloth: PlayerBot.clothSurplus]).isEmpty)
}
