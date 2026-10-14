import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-forestry: rival-towns.

private func anchor(_ command: Command?) -> TileCoordinate? {
    if case let .rivalPlace(_, _, anchor) = command { anchor } else { nil }
}

/// An archipelago whose rival 1 has placed its opening lumberjack hut,
/// is past its opening and holds enough food, wood and planks that no
/// other threshold rule applies.
private func rivalWithOneHut() throws -> (world: World, hut: TileCoordinate) {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .lumberjackHut)
    let hut = try #require(anchor(commands.last))
    world.tick()
    #expect(world.occupiedTiles[hut].flatMap { world.buildings[$0]?.kind } == .lumberjackHut)
    world.setRival(1) { $0.ai.scriptIndex = 12 }
    world.setRivalStock(1, [.wood: 20, .planks: 10, .food: 10])
    world.setRival(1) { $0.treasury = 5000 }
    return (world, hut)
}

/// Open grass tiles in both the forester's and the hut's catchment.
private func sharedOpenGrass(forester: TileCoordinate, hut: TileCoordinate, in world: World) -> Int {
    let footprint = Footprint(width: 2, height: 2)
    let isOpen = world.openGrass(for: .rival(1), tileToIsland: world.tileToIslandMap())
    var hutTiles = Set<TileCoordinate>()
    world.visitCatchment(anchor: hut, footprint: footprint, where: isOpen) { tile in
        hutTiles.insert(tile)
        return true
    }
    let site = Set(footprint.tiles(anchor: forester))
    var shared = 0
    world.visitCatchment(anchor: forester, footprint: footprint, where: isOpen) { tile in
        if hutTiles.contains(tile), !site.contains(tile) { shared += 1 }
        return true
    }
    return shared
}

@Test("scenario: rival replants beside its hut")
func scenarioRivalReplantsBesideItsHut() throws {
    var (world, _) = try rivalWithOneHut()
    world.testAddBuilding(.lumberjackHut, owner: .rival(1))
    world.testAddBuilding(.forester, owner: .rival(1))
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .forester)
    #expect(world.rival(1)?.ai.scriptIndex == 12)
}

@Test("scenario: rival forester needs open ground beside a hut")
func scenarioRivalForesterNeedsOpenGroundBesideAHut() {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    world.setRival(1) { $0.ai.scriptIndex = 12 }
    world.setRivalStock(1, [.wood: 20, .planks: 10, .food: 10])
    world.setRival(1) { $0.treasury = 5000 }
    // The only hut stands off the map, so no slot shares its catchment.
    world.testAddBuilding(.lumberjackHut, owner: .rival(1))
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) != .forester)
    #expect(world.rival(1)?.ai.scriptIndex == 13)
}

@Test("scenario: rival forester overlaps a hut")
func scenarioRivalForesterOverlapsAHut() throws {
    var (world, hut) = try rivalWithOneHut()
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .forester)
    let forester = try #require(anchor(commands.last))
    #expect(sharedOpenGrass(forester: forester, hut: hut, in: world) >= 4)
}

@Test func rivalForesterCostsNoMaterials() {
    let world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    #expect(world.materialCost(of: .forester, for: .rival(1)).isEmpty)
}
