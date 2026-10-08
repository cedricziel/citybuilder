import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-historical-ages.

private func game(_ age: Age) -> World {
    World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, age: age)
}

/// Puts `count` residents of `tier` into the world without building houses.
private func withResidents(_ world: inout World, _ count: Int, tier: HouseTier = .merchants) {
    var pop = HousePopulation()
    pop.tier = tier
    pop.population = UInt32(count)
    world.populations[EntityID(raw: 9999)] = pop
}

@Test("scenario: default age is medieval")
func scenarioDefaultAgeIsMedieval() {
    #expect(World.newGame().age == .medieval)
    #expect(World.newGame(layout: .singleIsland, seed: 0, culture: .mediterranean).age == .medieval)
}

@Test("scenario: snapshot carries the age")
func scenarioSnapshotCarriesTheAge() {
    #expect(game(.industrial).snapshot().age == .industrial)
}

@Test("scenario: years before christ")
func scenarioYearsBeforeChrist() {
    #expect(GameDate(year: -499, season: .spring).displayText == "Spring 500 BC")
    #expect(GameDate(year: 0, season: .winter).displayText == "Winter 1 BC")
    #expect(GameDate(year: 1, season: .summer).displayText == "Summer 1")
}

@Test("scenario: start in the renaissance")
func scenarioStartInTheRenaissance() {
    let world = game(.renaissance)
    #expect(world.date == GameDate(year: 1450, season: .spring))
    #expect(world.research.isResearched(.milling))
    #expect(world.research.isResearched(.feudalOrder))
    #expect(world.research.isResearched(.printingPress))
    #expect(!world.research.isResearched(.steamPower))
}

@Test("scenario: start in antiquity")
func scenarioStartInAntiquity() {
    let world = game(.antiquity)
    #expect(world.date == GameDate(year: -499, season: .spring))
    #expect(!world.research.isResearched(.milling))
    #expect(world.research.isResearched(.scholarship))
}

@Test("scenario: feudal order opens the medieval age")
func scenarioFeudalOrderOpensTheMedievalAge() {
    var world = game(.antiquity)
    withResidents(&world, 20, tier: .citizens)
    world.enqueue(.chooseResearch(.feudalOrder))
    world.tick()
    world.research.knowledge += Tech.feudalOrder.cost
    let events = world.tick().events
    #expect(world.age == .medieval)
    #expect(events.contains(.ageAdvanced(.medieval)))
    #expect(world.date.year == 1200)
}

@Test("scenario: calendar never goes back")
func scenarioCalendarNeverGoesBack() {
    var world = game(.medieval)
    world.calendar.startYear = 1500
    withResidents(&world, 20)
    world.enqueue(.chooseResearch(.printingPress))
    world.tick()
    world.research.knowledge += Tech.printingPress.cost
    world.tick()
    #expect(world.age == .renaissance)
    #expect(world.date.year == 1500)
}

@Test("scenario: windmill replaces the quern house")
func scenarioWindmillReplacesTheQuernHouse() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    world.research = ResearchState(researched: [.scholarship])
    world.enqueue(.place(.quernHouse, at: TileCoordinate(x: 1, y: 1)))
    for _ in 0 ..< 60 {
        world.tick()
    }
    let quern = try #require(world.occupiedTiles[TileCoordinate(x: 1, y: 1)])
    #expect(world.buildings[quern]?.state == .operational)
    world.research.markResearched(.milling)
    #expect(world.canPlace(.quernHouse, at: TileCoordinate(x: 4, y: 4)) == .rejected(.obsolete(.milling)))
    world.stockpiles[quern]?.deposit(.grain, amount: 2)
    var produced = false
    for _ in 0 ..< 100 where !produced {
        produced = world.tick().events.contains(.productionCycleCompleted(producer: quern, kind: .quernHouse))
    }
    #expect(produced)
}

@Test("scenario: quern house in antiquity")
func scenarioQuernHouseInAntiquity() throws {
    let recipe = try #require(ProductionCatalog.recipe(for: .quernHouse))
    #expect(recipe.inputs == [.grain: 2])
    #expect(recipe.outputs == [.flour: 1])
    #expect(recipe.cycleTicks == 80)
    #expect(game(.antiquity).canPlace(.quernHouse, at: TileCoordinate(x: 0, y: 0)) != .rejected(.obsolete(.milling)))
}

@Test("scenario: milling waits for the medieval age")
func scenarioMillingWaitsForTheMedievalAge() {
    var world = game(.antiquity)
    world.enqueue(.chooseResearch(.milling))
    world.tick()
    #expect(world.research.current == nil)
}

@Test("scenario: era tech needs residents")
func scenarioEraTechNeedsResidents() {
    var world = game(.antiquity)
    withResidents(&world, 19, tier: .citizens)
    world.enqueue(.chooseResearch(.feudalOrder))
    world.tick()
    #expect(world.research.current == nil)
}

@Test("scenario: era tech with enough residents")
func scenarioEraTechWithEnoughResidents() {
    var world = game(.antiquity)
    withResidents(&world, 20, tier: .citizens)
    world.enqueue(.chooseResearch(.feudalOrder))
    world.tick()
    #expect(world.research.current == .feudalOrder)
}

@Test("scenario: era techs open one age at a time")
func scenarioEraTechsOpenOneAgeAtATime() {
    var world = game(.antiquity)
    withResidents(&world, 20)
    world.enqueue(.chooseResearch(.printingPress))
    world.tick()
    #expect(world.research.current == nil)
}

@Test("scenario: quern house spec")
func scenarioQuernHouseSpec() {
    let spec = BuildingCatalog.spec(for: .quernHouse)
    #expect(spec.footprint == Footprint(width: 2, height: 2))
    #expect(spec.cost == 60)
    #expect(spec.materialCost == [.wood: 2, .planks: 2])
    #expect(BuildingKind.quernHouse.obsoletedBy == .milling)
}
