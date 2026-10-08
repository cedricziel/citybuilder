import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-culture-signatures: mead hall,
// forum and temple garden (milestone M2).

private typealias Fixture = SignatureFixture

/// A house at (6, 2); a 3×3 source `gap` tiles east of it sits at
/// x = 7 + gap.
private let houseAnchor = TileCoordinate(x: 6, y: 2)

private func east(_ gap: Int) -> TileCoordinate {
    TileCoordinate(x: 7 + gap, y: 2)
}

/// Puts a culture signature into the world, served with a stock of its
/// luxury when `served`.
@discardableResult
private func signature(_ kind: BuildingKind, at anchor: TileCoordinate, served: Bool, in world: inout World) -> EntityID {
    served ? Fixture.fuelled(kind, at: anchor, in: &world) : Fixture.inject(kind, at: anchor, in: &world)
}

/// Runs to just before the next interval, gives the house its residents
/// and runs the interval tick.
private func intervalTick(
    _ interval: UInt64,
    house: EntityID?,
    tier: HouseTier,
    residents: UInt32,
    in world: inout World
) -> [WorldEvent] {
    Fixture.runUntilBefore(multipleOf: interval, in: &world)
    if let house {
        var pop = HousePopulation()
        pop.tier = tier
        pop.population = residents
        world.populations[house] = pop
    }
    return world.tick().events
}

private func taxCollected(_ events: [WorldEvent]) -> Int64? {
    events.lazy.compactMap { event -> Int64? in
        if case let .taxesCollected(amount) = event { return amount }
        return nil
    }.first
}

private func merchantTax(forums: [(gap: Int, served: Bool)], monument: Bool = false) -> Int64? {
    var world = Fixture.grass(width: 60)
    world.culture = .mediterranean
    if monument {
        let id = Fixture.inject(.monument, at: TileCoordinate(x: 40, y: 20), in: &world)
        world.buildings[id]?.projectStages = World.monumentStages
    }
    let house = Fixture.inject(.house, at: houseAnchor, in: &world)
    for (index, forum) in forums.enumerated() {
        signature(.forum, at: TileCoordinate(x: 7 + forum.gap, y: 2 + index * 4), served: forum.served, in: &world)
    }
    return taxCollected(intervalTick(Economy.taxIntervalTicks, house: house, tier: .merchants, residents: 8, in: &world))
}

// MARK: - Coverage

@Test("an unserved culture signature is still active")
func unservedCultureSignatureIsActive() {
    var world = Fixture.grass()
    let hall = Fixture.inject(.meadHall, at: TileCoordinate(x: 2, y: 2), in: &world)
    #expect(world.buildings[hall]?.isSignatureActive == true)
    #expect(world.buildings[hall]?.isServed == false)
    #expect(world.activeSignatureSources().map(\.id) == [hall])
}

@Test("scenario: two forums count once")
func scenarioTwoForumsCountOnce() {
    #expect(merchantTax(forums: [(8, false), (2, false)]) == 40)
}

@Test("a served forum beats an unserved one covering the same house")
func servedForumBeatsUnserved() {
    #expect(merchantTax(forums: [(8, false), (2, true)]) == 48)
}

// MARK: - Forum

@Test("scenario: forum tax")
func scenarioForumTax() {
    #expect(merchantTax(forums: [(8, false)]) == 40)
}

@Test("scenario: wine served")
func scenarioWineServed() {
    #expect(merchantTax(forums: [(8, true)]) == 48)
}

@Test("scenario: house out of range")
func scenarioHouseOutOfRange() {
    #expect(merchantTax(forums: [(9, true)]) == 32)
}

@Test("scenario: forum and monument")
func scenarioForumAndMonument() {
    #expect(merchantTax(forums: [(8, true)], monument: true) == 52)
}

// MARK: - Mead hall

/// Upkeep of one interval with a mead hall at (2, 2), a sawmill at
/// `sawmill` and, when `bakery`, a bakery at (2, 7).
private func meadHallUpkeep(served: Bool, sawmill: TileCoordinate = TileCoordinate(x: 7, y: 2), bakery: Bool = true) -> Int64 {
    var world = Fixture.grass(width: 60)
    signature(.meadHall, at: TileCoordinate(x: 2, y: 2), served: served, in: &world)
    Fixture.inject(.sawmill, at: sawmill, in: &world)
    if bakery {
        Fixture.inject(.bakery, at: TileCoordinate(x: 2, y: 7), in: &world)
    }
    Fixture.runUntilBefore(multipleOf: Economy.upkeepIntervalTicks, in: &world)
    let before = world.economy.balance
    world.tick()
    return before - world.economy.balance
}

@Test("scenario: unserved mead hall")
func scenarioUnservedMeadHall() {
    #expect(meadHallUpkeep(served: false) == 2)
}

@Test("scenario: beer served")
func scenarioBeerServed() {
    #expect(meadHallUpkeep(served: true) == 1)
}

@Test("buildings beyond 8 tiles of a mead hall pay full upkeep")
func meadHallRange() {
    #expect(meadHallUpkeep(served: true, sawmill: TileCoordinate(x: 14, y: 2), bakery: false) == 3)
}

// MARK: - Temple garden

private func templeKnowledge(served: Bool, tier: HouseTier, residents: UInt32, research: Tech? = nil) -> World {
    var world = Fixture.grass()
    world.culture = .eastAsian
    world.research = ResearchState(researched: [], current: research)
    let house = Fixture.inject(.house, at: houseAnchor, in: &world)
    signature(.templeGarden, at: east(6), served: served, in: &world)
    _ = intervalTick(World.residentKnowledgeIntervalTicks, house: house, tier: tier, residents: residents, in: &world)
    return world
}

@Test("scenario: temple knowledge")
func scenarioTempleKnowledge() {
    #expect(templeKnowledge(served: false, tier: .citizens, residents: 6).research.knowledge == 12)
}

@Test("scenario: tea served")
func scenarioTeaServed() {
    #expect(templeKnowledge(served: true, tier: .citizens, residents: 6).research.knowledge == 18)
}

@Test("scenario: peasants don't meditate")
func scenarioPeasantsDontMeditate() {
    #expect(templeKnowledge(served: true, tier: .peasants, residents: 4).research.knowledge == 0)
}

@Test("scenario: temple speeds up research")
func scenarioTempleSpeedsUpResearch() {
    let world = templeKnowledge(served: true, tier: .citizens, residents: 6, research: .milling)
    #expect(world.research.current == .milling)
    #expect(world.research.progress == 18)
}
