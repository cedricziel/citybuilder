import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/fix-playable-foundation:
// goods-and-production (farm), buildings-and-construction (farm
// building, starter inventory), warehouses-and-logistics (town center
// as goods buffer, tie-break), population-and-needs (town center
// supplies needs).

private func injectBuffer(
    _ kind: BuildingKind,
    in world: inout World,
    at anchor: TileCoordinate,
    capacity: Int,
    contents: [Good: Int] = [:]
) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, ticksSincePlacement: 0)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    var stockpile = Stockpile(capacity: capacity)
    for (good, amount) in contents {
        _ = stockpile.deposit(good, amount: amount)
    }
    world.stockpiles[id] = stockpile
    return id
}

private func placeRoad(in world: inout World, y: Int, xs: ClosedRange<Int>) {
    for x in xs {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: y)))
    }
}

private func tick(_ world: inout World, _ count: Int) {
    for _ in 0 ..< count {
        world.tick()
    }
}

private func building(at anchor: TileCoordinate, in world: World) throws -> EntityID {
    try #require(world.occupiedTiles[anchor])
}

private func townCenterID(in world: World) throws -> EntityID {
    try #require(world.buildings.values.first { $0.kind == .townCenter }?.id)
}

/// First anchor on the main island where `footprint` covers only
/// unoccupied grass or forest.
private func freeLandAnchor(_ footprint: Footprint, in world: World) -> TileCoordinate? {
    for y in 0 ..< world.mapHeight - footprint.height {
        for x in 0 ..< world.mapWidth - footprint.width {
            let anchor = TileCoordinate(x: x, y: y)
            let free = footprint.tiles(anchor: anchor).allSatisfy { tile in
                let terrain = world.terrain(at: tile)
                return (terrain == .grass || terrain == .forest) && world.occupiedTiles[tile] == nil
            }
            if free {
                return anchor
            }
        }
    }
    return nil
}

// MARK: - Farm

@Test("scenario: farm spec exposes its footprint and costs")
func scenarioFarmSpecExposesItsFootprintAndCosts() {
    let spec = BuildingCatalog.spec(for: .farm)
    #expect(spec.footprint == Footprint(width: 2, height: 2))
    #expect(spec.cost == 60)
    #expect(spec.materialCost == [.wood: 2])
    #expect(spec.shorePlacement == nil)
}

@Test("scenario: farm produces food without inputs")
func scenarioFarmProducesFoodWithoutInputs() throws {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.farm, at: anchor))
    world.tick()
    let id = try building(at: anchor, in: world)
    while world.buildings[id]?.state != .operational {
        world.tick()
    }
    let before = world.stockpiles[id]?.quantity(of: .food) ?? 0
    tick(&world, 40)
    #expect(world.stockpiles[id]?.quantity(of: .food) == before + 1)
}

@Test("scenario: farm food satisfies a connected house")
func scenarioFarmFoodSatisfiesAConnectedHouse() throws {
    var world = World.fixtureWithTerrain(width: 14, height: 8, fill: .grass, seed: 1)
    let house = TileCoordinate(x: 1, y: 1)
    let farm = TileCoordinate(x: 5, y: 1)
    _ = injectBuffer(.warehouse, in: &world, at: TileCoordinate(x: 9, y: 0), capacity: 200)
    world.enqueue(.place(.house, at: house))
    world.enqueue(.place(.farm, at: farm))
    placeRoad(in: &world, y: 3, xs: 0 ... 12)
    tick(&world, 600)
    let houseID = try building(at: house, in: world)
    #expect(world.populations[houseID]?.foodSatisfied == true)
}

// MARK: - Town center as goods buffer

@Test("scenario: town center accepts carrier deposits")
func scenarioTownCenterAcceptsCarrierDeposits() {
    var world = World.fixtureWithTerrain(width: 12, height: 8, fill: .grass, seed: 1)
    let center = injectBuffer(.townCenter, in: &world, at: TileCoordinate(x: 7, y: 0), capacity: 40)
    world.enqueue(.place(.farm, at: TileCoordinate(x: 1, y: 1)))
    placeRoad(in: &world, y: 3, xs: 0 ... 10)
    tick(&world, 400)
    #expect((world.stockpiles[center]?.quantity(of: .food) ?? 0) > 0)
}

@Test("scenario: equidistant buffers tie-break on entity ID")
func scenarioEquidistantBuffersTieBreakOnEntityID() throws {
    var world = World.fixtureWithTerrain(width: 17, height: 8, fill: .grass, seed: 1)
    // Inject the right-hand warehouse first so it holds the lower ID;
    // hash-ordered iteration would pick either side.
    let right = injectBuffer(.warehouse, in: &world, at: TileCoordinate(x: 13, y: 0), capacity: 200)
    let left = injectBuffer(.warehouse, in: &world, at: TileCoordinate(x: 1, y: 0), capacity: 200)
    #expect(right.raw < left.raw)
    placeRoad(in: &world, y: 3, xs: 0 ... 16)
    tick(&world, 2)

    // Each warehouse's first adjacent road (row-major footprint scan)
    // is (1, 3) and (13, 3); from (7, 3) both are 6 steps away.
    let pick = try #require(world.findRoadConnectedBuffer(fromRoad: TileCoordinate(x: 7, y: 3), good: .food))
    #expect(pick.0 == right)
}

@Test("scenario: town center food satisfies a connected house")
func scenarioTownCenterFoodSatisfiesAConnectedHouse() throws {
    var world = World.fixtureWithTerrain(width: 10, height: 8, fill: .grass, seed: 1)
    _ = injectBuffer(.townCenter, in: &world, at: TileCoordinate(x: 5, y: 0), capacity: 40, contents: [.food: 4])
    let house = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.house, at: house))
    placeRoad(in: &world, y: 3, xs: 0 ... 8)
    tick(&world, 60)
    let houseID = try building(at: house, in: world)
    #expect(world.populations[houseID]?.foodSatisfied == true)
}

@Test("scenario: unconnected town center does not satisfy needs")
func scenarioUnconnectedTownCenterDoesNotSatisfyNeeds() throws {
    var world = World.fixtureWithTerrain(width: 12, height: 10, fill: .grass, seed: 1)
    _ = injectBuffer(.townCenter, in: &world, at: TileCoordinate(x: 8, y: 6), capacity: 40, contents: [.food: 4])
    let house = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.house, at: house))
    placeRoad(in: &world, y: 3, xs: 0 ... 4)
    tick(&world, 60)
    let houseID = try building(at: house, in: world)
    #expect(world.populations[houseID]?.foodSatisfied == false)
}

// MARK: - Starter inventory

@Test("scenario: starter goods afford a lumberjack, a farm, and a house")
func scenarioStarterGoodsAffordALumberjackAFarmAndAHouse() throws {
    var world = World.newGame()
    world.economy.credit(100_000)
    for kind in [BuildingKind.lumberjackHut, .farm, .house] {
        let anchor = try #require(freeLandAnchor(BuildingCatalog.spec(for: kind).footprint, in: world))
        #expect(world.canPlace(kind, at: anchor) == .allowed, "\(kind)")
        world.enqueue(.place(kind, at: anchor))
        world.tick()
    }
    let center = try townCenterID(in: world)
    #expect(world.stockpiles[center]?.quantity(of: .wood) == 2)
    #expect(world.stockpiles[center]?.quantity(of: .planks) == 0)
}

@Test("scenario: port accepts carrier deposits")
func scenarioPortAcceptsCarrierDeposits() {
    var world = World.fixtureWithTerrain(width: 12, height: 8, fill: .grass, seed: 1)
    let port = injectBuffer(.port, in: &world, at: TileCoordinate(x: 7, y: 0), capacity: 200)
    world.enqueue(.place(.farm, at: TileCoordinate(x: 1, y: 1)))
    placeRoad(in: &world, y: 3, xs: 0 ... 10)
    tick(&world, 400)
    #expect((world.stockpiles[port]?.quantity(of: .food) ?? 0) > 0)
}

@Test("scenario: full buffer rejects deposits")
func scenarioFullBufferRejectsDeposits() throws {
    var world = World.fixtureWithTerrain(width: 17, height: 8, fill: .grass, seed: 1)
    let near = injectBuffer(.townCenter, in: &world, at: TileCoordinate(x: 6, y: 0), capacity: 1, contents: [.wood: 1])
    let far = injectBuffer(.warehouse, in: &world, at: TileCoordinate(x: 13, y: 0), capacity: 200)
    placeRoad(in: &world, y: 3, xs: 0 ... 16)
    tick(&world, 2)

    let pick = try #require(world.findRoadConnectedBuffer(fromRoad: TileCoordinate(x: 5, y: 3), good: .food))
    #expect(pick.0 == far)
    #expect(pick.0 != near)
}
