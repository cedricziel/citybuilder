import Foundation
import Testing
@testable import CityCore

// Ownership scenarios from openspec/changes/add-rival-towns:
// buildings-and-construction, sea-transport, economy and
// population-and-needs.

private let homeIsland: IslandID = 3

// MARK: - buildings-and-construction

@Test("scenario: player placement")
func scenarioPlayerPlacement() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let anchor = try #require(world.testFirstPlaceable(.house, onIsland: homeIsland, for: .player))
    world.enqueue(.place(.house, at: anchor))
    world.tick()
    let id = try #require(world.occupiedTiles[anchor])
    #expect(world.buildings[id]?.owner == .player)
}

@Test("scenario: rival placement")
func scenarioRivalPlacement() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let rival = try #require(world.rival(2))
    let anchor = try #require(world.testFirstPlaceable(.farm, onIsland: rival.islandID, for: .rival(2)))
    let balance = world.economy.balance
    world.enqueue(.rivalPlace(2, .farm, at: anchor))
    world.tick()
    let id = try #require(world.occupiedTiles[anchor])
    #expect(world.buildings[id]?.owner == .rival(2))
    #expect(world.rival(2)?.treasury == rival.treasury - 60)
    #expect(world.economy.balance == balance)
}

@Test("scenario: player builds on a rival island")
func scenarioPlayerBuildsOnARivalIsland() throws {
    let world = World.newGame(layout: .archipelago, seed: 0, difficulty: .hard)
    let rival = try #require(world.rival(1))
    // A free grass slot: the road needs no materials.
    let anchor = try #require(world.testFirstPlaceable(.road, onIsland: rival.islandID, for: .rival(1)))
    #expect(world.canPlace(.house, at: anchor) == .rejected(.foreignIsland(.rival(1))))
}

@Test("scenario: rival builds without research")
func scenarioRivalBuildsWithoutResearch() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    world.research = ResearchState(researched: [])
    let rival = try #require(world.rival(1))
    let anchor = try #require(world.testFirstPlaceable(.sawmill, onIsland: rival.islandID, for: .rival(1)))
    #expect(world.canPlace(.sawmill, at: anchor, for: .rival(1)) == .allowed)
    // A locked kind is open to the rival, though not to the player.
    let windmill = try #require(world.testFirstPlaceable(.windmill, onIsland: rival.islandID, for: .rival(1)))
    #expect(world.canPlace(.windmill, at: windmill, for: .rival(1)) == .allowed)
    let home = try #require(world.testFirstPlaceable(.house, onIsland: homeIsland, for: .player))
    #expect(world.canPlace(.windmill, at: home) == .rejected(.locked(.milling)))
}

@Test("scenario: demolishing a rival house")
func scenarioDemolishingARivalHouse() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let rival = try #require(world.rival(1))
    let anchor = try #require(world.testFirstPlaceable(.house, onIsland: rival.islandID, for: .rival(1)))
    world.enqueue(.rivalPlace(1, .house, at: anchor))
    world.tick()
    let id = try #require(world.occupiedTiles[anchor])
    world.enqueue(.demolish(at: anchor))
    let events = world.tick().events
    #expect(world.buildings[id] != nil)
    #expect(!events.contains { if case .buildingDemolished = $0 { true } else { false } })
}

@Test("scenario: clearing a rival forest")
func scenarioClearingARivalForest() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let rival = try #require(world.rival(1))
    let forest = try #require(world.testFirstForest(onIsland: rival.islandID))
    world.enqueue(.harvestForest(at: forest))
    world.tick()
    #expect(world.terrain(at: forest) == .forest)
}

// MARK: - sea-transport

@Test("scenario: ship inherits the shipyard's owner")
func scenarioShipInheritsTheShipyardsOwner() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    world.seedUnlimitedTestInventory()
    world.research = .everything
    world.economy.credit(10000)
    let anchor = try #require(world.testFirstPlaceable(.shipyard, onIsland: homeIsland, for: .player))
    world.enqueue(.place(.shipyard, at: anchor))
    world.tick()
    let shipyard = try #require(world.occupiedTiles[anchor])
    let emitted = world.emitShip(fromShipyard: shipyard)
    let ship = try #require(emitted)
    #expect(world.ships[ship]?.owner == .player)
}

@Test("scenario: old ship decodes as the player's")
func scenarioOldShipDecodesAsThePlayers() throws {
    let ship = Ship(
        id: EntityID(raw: 7), position: Fixed2D(x: Fixed(1), y: Fixed(2)), heading: .zero,
        routeID: nil, waypointIdx: 0, cargo: [:], state: .idle, shipClass: .default, owner: .rival(2)
    )
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ship)) as? [String: Any])
    #expect(json["owner"] as? String == "rival-2")
    json.removeValue(forKey: "owner")
    let decoded = try JSONDecoder().decode(Ship.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(decoded.owner == .player)
}

// MARK: - economy

@Test("scenario: upkeep split by owner")
func scenarioUpkeepSplitByOwner() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .hard)
    for _ in 0 ..< 2 {
        world.testAddBuilding(.sawmill, owner: .player)
        world.testAddBuilding(.sawmill, owner: .rival(1))
    }
    _ = world.testRun(ticks: 49)
    let balance = world.economy.balance
    let treasury = try #require(world.rival(1)).treasury
    let events = world.tick().events
    #expect(world.economy.balance == balance - 5)
    #expect(world.rival(1)?.treasury == treasury - 4)
    #expect(events.contains(.upkeepPaid(amount: 5)))
}

@Test("scenario: only rivals earn tax")
func scenarioOnlyRivalsEarnTax() {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    _ = world.testRun(ticks: 49)
    world.testAddResidents(8, owner: .rival(1))
    let balance = world.economy.balance
    let events = world.tick().events
    #expect(world.economy.balance == balance)
    #expect(!events.contains { if case .taxesCollected = $0 { true } else { false } })
}

// MARK: - population-and-needs

@Test("scenario: total population")
func scenarioTotalPopulation() {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    world.testAddResidents(30, owner: .player)
    world.testAddResidents(50, owner: .rival(1))
    #expect(world.snapshot().totalPopulation == 30)
}

@Test("scenario: era gate ignores rivals")
func scenarioEraGateIgnoresRivals() {
    var world = World.newGame(layout: .archipelago, seed: 0, age: .antiquity, difficulty: .normal)
    world.testAddResidents(10, owner: .player, tier: .citizens)
    world.testAddResidents(30, owner: .rival(1), tier: .citizens)
    #expect(!world.canChooseResearch(.feudalOrder))
}
