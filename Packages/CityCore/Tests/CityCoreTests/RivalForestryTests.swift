import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-forestry: rival-towns.

/// An archipelago whose rival 1 has placed its opening lumberjack hut,
/// is past its opening and holds enough food, wood and planks that no
/// other threshold rule applies.
private func rivalWithOneHut() throws -> (world: World, hut: TileCoordinate) {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .lumberjackHut)
    let hut = try #require(placedAnchor(commands.last))
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

/// Catchment tiles of a 2×2 building at `anchor`, its own tiles left out.
private func catchment(of anchor: TileCoordinate) -> Set<TileCoordinate> {
    let site = Set(Footprint(width: 2, height: 2).tiles(anchor: anchor))
    return Set((anchor.y - 2 ... anchor.y + 3).flatMap { y in
        (anchor.x - 2 ... anchor.x + 3).map { TileCoordinate(x: $0, y: y) }
    }).subtracting(site)
}

/// Unoccupied grass or forest on rival 1's island.
private func isFreeLand(_ tile: TileCoordinate, in world: World) -> Bool {
    let island = world.rival(1)?.islandID
    return world.tileToIslandMap()[tile] == island && world.occupiedTiles[tile] == nil
        && [.grass, .forest].contains(world.terrain(at: tile))
}

/// Turns every grass tile within 12 of `center` into forest, then
/// `grass` back into grass, so those are the only open grass there.
private func keepOnlyGrass(_ grass: [TileCoordinate], around center: TileCoordinate, in world: inout World) {
    for y in center.y - 12 ... center.y + 12 {
        for x in center.x - 12 ... center.x + 12 {
            let tile = TileCoordinate(x: x, y: y)
            if world.terrain(at: tile) == .grass { world.terrainGrid[y * world.mapWidth + x] = .forest }
        }
    }
    for tile in grass {
        world.terrainGrid[tile.y * world.mapWidth + tile.x] = .grass
    }
}

/// The rival-with-one-hut world, the forester slot it picks there, and
/// the free tiles in both that slot's and the hut's catchment.
private struct ForesterSetUp {
    var world: World
    let hut: TileCoordinate
    let slot: TileCoordinate
    let shared: [TileCoordinate]
}

private func foresterSetUp() throws -> ForesterSetUp {
    let (world, hut) = try rivalWithOneHut()
    var probe = world
    let slot = try #require(placedAnchor(probe.takeTurn(1).last))
    let shared = catchment(of: slot).intersection(catchment(of: hut))
        .subtracting(Footprint(width: 2, height: 2).tiles(anchor: slot))
        .filter { isFreeLand($0, in: world) }
        .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
    return ForesterSetUp(world: world, hut: hut, slot: slot, shared: shared)
}

@Test("scenario: rival forester needs open ground beside a hut")
func scenarioRivalForesterNeedsOpenGroundBesideAHut() throws {
    let setUp = try foresterSetUp()
    var world = setUp.world
    let hut = setUp.hut, shared = setUp.shared
    try #require(shared.count >= 4)
    var control = world
    keepOnlyGrass(Array(shared.prefix(4)), around: hut, in: &control)
    #expect(placedKind(control.takeTurn(1).last) == .forester)
    keepOnlyGrass(Array(shared.prefix(3)), around: hut, in: &world)
    #expect(placedKind(world.takeTurn(1).last) != .forester)
}

@Test("rival forester counts open grass per hut, not across huts")
func rivalForesterCountsOpenGrassPerHut() throws {
    let setUp = try foresterSetUp()
    var world = setUp.world
    let hut = setUp.hut, slot = setUp.slot, shared = setUp.shared
    let site = Set(Footprint(width: 2, height: 2).tiles(anchor: slot)).union(Footprint(width: 2, height: 2).tiles(anchor: hut))
    // A second hut whose catchment reaches 2 tiles of the slot's
    // catchment that the first hut does not reach, and none it does.
    var second: (anchor: TileCoordinate, grass: [TileCoordinate])?
    search: for dy in -8 ... 8 {
        for dx in -8 ... 8 {
            let anchor = TileCoordinate(x: hut.x + dx, y: hut.y + dy)
            let tiles = Footprint(width: 2, height: 2).tiles(anchor: anchor)
            guard tiles.allSatisfy({ isFreeLand($0, in: world) && !site.contains($0) }) else { continue }
            let reach = catchment(of: anchor)
            let own = catchment(of: slot).intersection(reach).subtracting(catchment(of: hut)).subtracting(site)
                .subtracting(tiles).filter { isFreeLand($0, in: world) }.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
            let firstOnly = shared.filter { !reach.contains($0) && !tiles.contains($0) }
            if own.count >= 2, firstOnly.count >= 2 {
                second = (anchor, Array(own.prefix(2) + firstOnly.prefix(2)))
                break search
            }
        }
    }
    let pick = try #require(second)
    world.testPlace(.lumberjackHut, at: pick.anchor, owner: .rival(1))
    keepOnlyGrass(pick.grass, around: hut, in: &world)
    #expect(placedKind(world.takeTurn(1).last) != .forester)
}

@Test("scenario: rival forester overlaps a hut")
func scenarioRivalForesterOverlapsAHut() throws {
    var (world, hut) = try rivalWithOneHut()
    let commands = world.takeTurn(1)
    #expect(placedKind(commands.last) == .forester)
    let forester = try #require(placedAnchor(commands.last))
    #expect(sharedOpenGrass(forester: forester, hut: hut, in: world) >= 4)
}

@Test func rivalForesterCostsNoMaterials() {
    let world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    #expect(world.materialCost(of: .forester, for: .rival(1)).isEmpty)
}

@Test func determinismFixtureWorldPlantsForest() {
    // The world DeterminismFixture compares across platforms must
    // exercise forestry, or a platform difference in it would go unseen.
    var world = World.newGame(layout: .archipelago, seed: 0xC17B)
    let planted = world.testRun(ticks: 6000).count { if case .forestPlanted = $0 { true } else { false } }
    #expect(world.buildings.values.contains { $0.kind == .forester })
    #expect(planted > 0)
}

@Test func foresterMidCycleSurvivesASaveRoundTrip() throws {
    var world = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1)
    let id = world.testPlace(.forester, at: TileCoordinate(x: 4, y: 4), owner: .player)
    _ = world.testRun(ticks: 25)
    #expect(world.productions[id]?.ticksThisCycle == 25)
    var loaded = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(world))
    #expect(loaded == world)
    let before = loaded.testRun(ticks: 14)
    #expect(!before.contains { if case .forestPlanted = $0 { true } else { false } })
    #expect(loaded.tick().events.contains(.forestPlanted(at: TileCoordinate(x: 2, y: 2), forester: id)))
}
