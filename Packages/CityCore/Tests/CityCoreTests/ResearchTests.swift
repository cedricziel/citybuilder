import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-research.

@Test("scenario: a library produces knowledge")
func scenarioALibraryProducesKnowledge() throws {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    world.enqueue(.place(.library, at: TileCoordinate(x: 1, y: 1)))
    world.tick()
    let id = try #require(world.occupiedTiles[TileCoordinate(x: 1, y: 1)])
    while world.buildings[id]?.state != .operational || !world.tickCount.isMultiple(of: 10) {
        world.tick()
    }
    let before = world.research.knowledge
    for _ in 0 ..< 100 {
        world.tick()
    }
    #expect(world.research.knowledge - before == 10)
}

@Test("scenario: new game starts with scholarship only")
func scenarioNewGameStartsWithScholarshipOnly() {
    let research = World.newGame().research
    #expect(research.isResearched(.scholarship))
    for tech in [Tech.milling, .mining, .metallurgy, .seafaring] {
        #expect(!research.isResearched(tech), "\(tech)")
    }
}

@Test("scenario: research completes when its cost is reached")
func scenarioResearchCompletesWhenItsCostIsReached() {
    var world = World.newGame()
    world.enqueue(.chooseResearch(.milling))
    world.tick()
    #expect(world.research.current == .milling)
    world.research.knowledge += 40
    world.tick()
    #expect(world.research.isResearched(.milling))
    #expect(world.research.current == nil)
}

@Test("scenario: a tech with unmet prerequisites cannot be chosen")
func scenarioATechWithUnmetPrerequisitesCannotBeChosen() {
    var world = World.newGame()
    world.enqueue(.chooseResearch(.metallurgy))
    world.tick()
    #expect(world.research.current == nil)
}

@Test("scenario: mine is locked before mining")
func scenarioMineIsLockedBeforeMining() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .mountain, seed: 1)
    world.research = .initial
    #expect(world.canPlace(.mine, at: TileCoordinate(x: 1, y: 1)) == .rejected(.locked(.mining)))
}

@Test("scenario: library spec exposes its footprint and costs")
func scenarioLibrarySpecExposesItsFootprintAndCosts() {
    let spec = BuildingCatalog.spec(for: .library)
    #expect(spec.footprint == Footprint(width: 2, height: 2))
    #expect(spec.cost == 100)
    #expect(spec.materialCost == [.wood: 2, .planks: 4])
}

@Test("switching research returns progress to knowledge")
func switchingResearchReturnsProgress() {
    var world = World.newGame()
    world.enqueue(.chooseResearch(.mining))
    world.tick()
    world.research.knowledge += 10
    world.tick()
    world.enqueue(.chooseResearch(.milling))
    world.tick()
    #expect(world.research.current == .milling)
    #expect(world.research.progress + world.research.knowledge >= 10)
}
