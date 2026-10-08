import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/fix-playable-foundation:
// goods-and-production (input supply, lumberjack catchment) and
// population-and-needs (shared road network).

private func inject(
    _ kind: BuildingKind,
    in world: inout World,
    at anchor: TileCoordinate,
    contents: [Good: Int] = [:]
) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, ticksSincePlacement: 0)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    var stockpile = Stockpile(capacity: kind == .sawmill ? 16 : 200)
    for (good, amount) in contents {
        _ = stockpile.deposit(good, amount: amount)
    }
    world.stockpiles[id] = stockpile
    return id
}

private func roads(_ world: inout World, y: Int, _ xs: ClosedRange<Int>) {
    for x in xs {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: y)))
    }
    world.tick()
}

private func supplyCarriers(to consumer: EntityID, in world: World) -> Int {
    world.carriers.values.count { carrier in
        if case let .retrieve(_, _, _, toConsumer) = carrier.mission { return toConsumer == consumer }
        return false
    }
}

// MARK: - Input supply

@Test("scenario: sawmill receives wood from a connected warehouse")
func scenarioSawmillReceivesWoodFromAConnectedWarehouse() {
    var world = World.fixtureWithTerrain(width: 14, height: 6, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    let sawmill = inject(.sawmill, in: &world, at: TileCoordinate(x: 1, y: 1))
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 9, y: 0), contents: [.wood: 5])
    roads(&world, y: 3, 0 ... 12)
    for _ in 0 ..< 30 {
        world.tick()
    }
    let delivered = (world.stockpiles[sawmill]?.quantity(of: .wood) ?? 0)
        + (world.stockpiles[sawmill]?.quantity(of: .planks) ?? 0)
    #expect(delivered > 0)
    #expect((world.stockpiles[warehouse]?.quantity(of: .wood) ?? 0) < 5)
}

@Test("scenario: no supply without a shared road network")
func scenarioNoSupplyWithoutASharedRoadNetwork() {
    var world = World.fixtureWithTerrain(width: 14, height: 6, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    let sawmill = inject(.sawmill, in: &world, at: TileCoordinate(x: 1, y: 1))
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 9, y: 0), contents: [.wood: 5])
    roads(&world, y: 3, 0 ... 4)
    roads(&world, y: 3, 7 ... 12)
    for _ in 0 ..< 30 {
        world.tick()
    }
    #expect(supplyCarriers(to: sawmill, in: world) == 0)
    #expect(world.stockpiles[warehouse]?.quantity(of: .wood) == 5)
}

@Test("scenario: input carriers respect the carrier cap")
func scenarioInputCarriersRespectTheCarrierCap() {
    var world = World.fixtureWithTerrain(width: 30, height: 6, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    let sawmill = inject(.sawmill, in: &world, at: TileCoordinate(x: 1, y: 1))
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 25, y: 0), contents: [.wood: 20])
    roads(&world, y: 3, 0 ... 28)
    for _ in 0 ..< 40 {
        world.tick()
        #expect(supplyCarriers(to: sawmill, in: world) <= CarrierConfig.perProducerCap)
    }
}

// MARK: - Lumberjack catchment

@Test("scenario: lumberjack harvests forest two tiles away")
func scenarioLumberjackHarvestsForestTwoTilesAway() {
    var world = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 4, y: 4)
    let id = inject(.lumberjackHut, in: &world, at: anchor)
    let forest = TileCoordinate(x: 7, y: 4) // two tiles east of the 2×2 footprint's right edge (x = 5)
    world.terrainGrid[forest.y * 10 + forest.x] = .forest
    for _ in 0 ..< 31 {
        world.tick()
    }
    #expect((world.stockpiles[id]?.quantity(of: .wood) ?? 0) >= 1)
    #expect(world.terrain(at: forest) == .grass)
}

@Test("scenario: lumberjack stalls once its catchment is cleared")
func scenarioLumberjackStallsOnceItsCatchmentIsCleared() {
    var world = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1)
    let id = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 2, y: 2))
    world.terrainGrid[2 * 12 + 9] = .forest // three tiles from the footprint
    for _ in 0 ..< 60 {
        world.tick()
    }
    #expect((world.stockpiles[id]?.quantity(of: .wood) ?? 0) == 0)
}

// MARK: - Shared road network for needs

@Test("scenario: separate road networks do not share goods")
func scenarioSeparateRoadNetworksDoNotShareGoods() throws {
    var world = World.fixtureWithTerrain(width: 16, height: 8, fill: .grass, seed: 1)
    _ = inject(.townCenter, in: &world, at: TileCoordinate(x: 11, y: 0), contents: [.food: 4])
    let house = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.house, at: house))
    roads(&world, y: 3, 0 ... 4)
    roads(&world, y: 3, 7 ... 14)
    for _ in 0 ..< 60 {
        world.tick()
    }
    let houseID = try #require(world.occupiedTiles[house])
    #expect(world.populations[houseID]?.isSatisfied(.food) == false)
}
