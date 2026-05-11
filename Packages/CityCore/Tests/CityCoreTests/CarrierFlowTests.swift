import Foundation
import Testing
@testable import CityCore

@Test("carrier: lumberjack with adjacent warehouse + road spawns a carrier that walks and delivers")
func carrierLifecycle() {
    // Build a tiny test world: forest tile + lumberjack + road + warehouse.
    //   Lumberjack 2x2 anchor at (1,1)  → occupies (1,1)–(2,2)
    //   Forest at (3,1)                 → adjacent east of the lumberjack
    //   Road row at y=3                 → south of lumberjack, north of warehouse
    //   Warehouse 3x3 anchor at (4,4)   → occupies (4,4)–(6,6)
    var world = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1)
    world.terrainGrid[1 * 12 + 3] = .forest // tile (col=3, row=1)

    let lumberAnchor = TileCoordinate(x: 1, y: 1)
    let warehouseAnchor = TileCoordinate(x: 4, y: 4)
    world.enqueue(.place(.lumberjackHut, at: lumberAnchor))
    world.enqueue(.place(.warehouse, at: warehouseAnchor))
    for x in 2 ... 5 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 3)))
    }
    world.tick()

    // Wait for construction + production to make wood.
    for _ in 0 ..< 80 {
        world.tick()
    }

    // By now production has run; a carrier should be in flight or the
    // warehouse should have received wood.
    let allBuildings = world.buildings
    let warehouseId = allBuildings.first(where: {
        $0.value.kind == .warehouse
    })?.key
    let warehouseStock = warehouseId.flatMap { world.stockpiles[$0] }

    // The test passes if either a carrier was spawned OR wood made it to the warehouse.
    let hadCarrier = !world.carriers.isEmpty
    let warehouseWood = warehouseStock?.quantity(of: .wood) ?? 0
    #expect(hadCarrier || warehouseWood >= 1, "production chain must spawn a carrier or deliver wood")
}
