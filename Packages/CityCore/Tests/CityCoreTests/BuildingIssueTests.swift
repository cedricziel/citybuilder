import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/fix-mac-playtest-findings:
// warehouses-and-logistics / Buildings report why they are idle.

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
    if var stockpile = World.newStockpile(for: kind) {
        for (good, amount) in contents {
            _ = stockpile.deposit(good, amount: amount)
        }
        world.stockpiles[id] = stockpile
    }
    return id
}

private func roads(_ world: inout World, y: Int, _ xs: ClosedRange<Int>) {
    for x in xs {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: y)))
    }
    world.tick()
}

private func grassWorld() -> World {
    var world = World.fixtureWithTerrain(width: 16, height: 6, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    return world
}

@Test("scenario: a producer without a road reports no road")
func scenarioAProducerWithoutARoadReportsNoRoad() {
    var world = grassWorld()
    let farm = inject(.farm, in: &world, at: TileCoordinate(x: 1, y: 1))
    #expect(world.buildingIssues()[farm] == .noRoad)
}

@Test("scenario: a producer off the storage network reports no route to storage")
func scenarioAProducerOffTheStorageNetworkReportsNoRouteToStorage() {
    var world = grassWorld()
    let farm = inject(.farm, in: &world, at: TileCoordinate(x: 1, y: 1))
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 11, y: 0))
    roads(&world, y: 3, 0 ... 5)
    roads(&world, y: 3, 8 ... 14)
    #expect(world.buildingIssues()[farm] == .noRouteToStorage)
}

@Test("scenario: a producer on the storage network reports no issue")
func scenarioAProducerOnTheStorageNetworkReportsNoIssue() {
    var world = grassWorld()
    let farm = inject(.farm, in: &world, at: TileCoordinate(x: 1, y: 1))
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 11, y: 0))
    roads(&world, y: 3, 0 ... 14)
    #expect(world.buildingIssues()[farm] == nil)
}

@Test("scenario: a lumberjack without forest reports no trees in reach")
func scenarioALumberjackWithoutForestReportsNoTreesInReach() {
    var world = grassWorld()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1))
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 11, y: 0))
    roads(&world, y: 3, 0 ... 14)
    #expect(world.buildingIssues()[hut] == .noTreesInReach)
}

@Test("scenario: a producer with a full store reports its output stuck")
func scenarioAProducerWithAFullStoreReportsItsOutputStuck() {
    var world = grassWorld()
    let farm = inject(.farm, in: &world, at: TileCoordinate(x: 1, y: 1))
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 11, y: 0))
    roads(&world, y: 3, 0 ... 14)
    _ = world.stockpiles[farm]?.deposit(.food, amount: 16)
    #expect(world.buildingIssues()[farm] == .outputStuck(.food))
}

@Test("scenario: a producer full of output reports it stuck, not short")
func scenarioAProducerFullOfOutputReportsItStuckNotShort() {
    var world = grassWorld()
    let sawmill = inject(.sawmill, in: &world, at: TileCoordinate(x: 1, y: 1))
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 11, y: 0))
    roads(&world, y: 3, 0 ... 14)
    _ = world.stockpiles[sawmill]?.deposit(.planks, amount: BuildingKind.sawmill.storage ?? 0)
    #expect(world.buildingIssues()[sawmill] == .outputStuck(.planks))
}

@Test("a producer full of inputs reports its output stuck")
func aProducerFullOfInputsReportsItsOutputStuck() {
    var world = grassWorld()
    let sawmill = inject(.sawmill, in: &world, at: TileCoordinate(x: 1, y: 1))
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 11, y: 0))
    roads(&world, y: 3, 0 ... 14)
    _ = world.stockpiles[sawmill]?.deposit(.wood, amount: BuildingKind.sawmill.storage ?? 0)
    #expect(world.buildingIssues()[sawmill] == .outputStuck(.planks))
}

@Test("scenario: a producer short of inputs reports the missing goods")
func scenarioAProducerShortOfInputsReportsTheMissingGoods() {
    var world = grassWorld()
    let sawmill = inject(.sawmill, in: &world, at: TileCoordinate(x: 1, y: 1))
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 11, y: 0))
    roads(&world, y: 3, 0 ... 14)
    #expect(world.buildingIssues()[sawmill] == .missingInputs([.wood]))
}

@Test("scenario: A house off every hub's road network reports no market in reach")
func scenarioAHouseOffEveryHubsRoadNetworkReportsNoMarketInReach() {
    var world = grassWorld()
    let house = inject(.house, in: &world, at: TileCoordinate(x: 1, y: 1))
    _ = inject(.townCenter, in: &world, at: TileCoordinate(x: 11, y: 0))
    roads(&world, y: 3, 0 ... 5)
    roads(&world, y: 3, 8 ... 14)
    #expect(world.buildingIssues()[house] == .noMarketInReach)
}

@Test("scenario: the snapshot carries building issues")
func scenarioTheSnapshotCarriesBuildingIssues() {
    var world = grassWorld()
    let farm = inject(.farm, in: &world, at: TileCoordinate(x: 1, y: 1))
    #expect(world.snapshot().buildingIssues[farm] == .noRoad)
}
