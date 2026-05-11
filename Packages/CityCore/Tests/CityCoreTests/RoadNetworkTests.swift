import Foundation
import Testing
@testable import CityCore

// Tests for spec road-network.

private func grassWorld() -> World {
    World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1)
}

@Test("scenario: road placement on grass")
func scenarioRoadPlacementOnGrass() {
    var world = grassWorld()
    world.enqueue(.place(.road, at: TileCoordinate(x: 4, y: 4)))
    world.tick()
    #expect(world.roadGraph.isConnected(TileCoordinate(x: 4, y: 4)))
}

@Test("scenario: road placement on water rejected")
func scenarioRoadPlacementOnWaterRejected() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .water, seed: 1)
    let target = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(.road, at: target))
    world.tick()
    #expect(!world.roadGraph.isConnected(target))
}

@Test("scenario: new road extends graph")
func scenarioNewRoadExtendsGraph() {
    var world = grassWorld()
    world.enqueue(.place(.road, at: TileCoordinate(x: 4, y: 4)))
    world.tick()
    world.enqueue(.place(.road, at: TileCoordinate(x: 5, y: 4)))
    world.tick()
    let lhs = TileCoordinate(x: 4, y: 4)
    let rhs = TileCoordinate(x: 5, y: 4)
    #expect(world.roadGraph.adjacency[lhs]?.contains(rhs) == true)
    #expect(world.roadGraph.adjacency[rhs]?.contains(lhs) == true)
}

@Test("scenario: removing road removes edges")
func scenarioRemovingRoadRemovesEdges() {
    var world = grassWorld()
    let tileA = TileCoordinate(x: 4, y: 4)
    let tileB = TileCoordinate(x: 5, y: 4)
    world.enqueue(.place(.road, at: tileA))
    world.enqueue(.place(.road, at: tileB))
    world.tick()
    #expect(world.roadGraph.adjacency[tileA]?.contains(tileB) == true)
    world.enqueue(.demolish(at: tileA))
    world.tick()
    #expect(world.roadGraph.adjacency[tileB]?.contains(tileA) != true)
    #expect(!world.roadGraph.isConnected(tileA))
}

@Test("scenario: adjacent road connects building")
func scenarioAdjacentRoadConnectsBuilding() {
    var world = grassWorld()
    let houseAnchor = TileCoordinate(x: 4, y: 4)
    let adjacent = TileCoordinate(x: 6, y: 4) // east of the 2x2 footprint
    world.enqueue(.place(.house, at: houseAnchor))
    world.enqueue(.place(.road, at: adjacent))
    world.tick()
    let connected = world.roadGraph.isAnchorRoadConnected(
        houseAnchor,
        footprint: BuildingCatalog.spec(for: .house).footprint
    )
    #expect(connected)
}

@Test("scenario: diagonal road does not connect")
func scenarioDiagonalRoadDoesNotConnect() {
    var world = grassWorld()
    let houseAnchor = TileCoordinate(x: 4, y: 4)
    // Diagonally beyond the 2x2 footprint:
    let diagonal = TileCoordinate(x: 6, y: 6)
    world.enqueue(.place(.house, at: houseAnchor))
    world.enqueue(.place(.road, at: diagonal))
    world.tick()
    let connected = world.roadGraph.isAnchorRoadConnected(
        houseAnchor,
        footprint: BuildingCatalog.spec(for: .house).footprint
    )
    #expect(!connected)
}

@Test("scenario: path found between connected buildings")
func scenarioPathFoundBetweenConnectedBuildings() {
    var world = grassWorld()
    // Lay a 5-tile horizontal road
    for x in 2 ... 6 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 5)))
    }
    world.tick()
    let path = PathFinder.path(
        from: TileCoordinate(x: 2, y: 5),
        to: TileCoordinate(x: 6, y: 5),
        in: world.roadGraph
    )
    let realPath = try? #require(path, "expected a path along the laid road")
    #expect(realPath?.count == 5)
}

@Test("scenario: disconnected buildings return no path")
func scenarioDisconnectedBuildingsReturnNoPath() {
    var world = grassWorld()
    world.enqueue(.place(.road, at: TileCoordinate(x: 2, y: 5)))
    world.enqueue(.place(.road, at: TileCoordinate(x: 6, y: 5)))
    world.tick()
    let path = PathFinder.path(
        from: TileCoordinate(x: 2, y: 5),
        to: TileCoordinate(x: 6, y: 5),
        in: world.roadGraph
    )
    #expect(path == nil)
}

@Test("scenario: cache invalidated on road change")
func scenarioCacheInvalidatedOnRoadChange() {
    var world = grassWorld()
    for x in 2 ... 6 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 5)))
    }
    world.tick()
    let gen1 = world.roadGraph.generation

    var cache = PathCache()
    cache.invalidate(currentGeneration: gen1)
    let key = PathCache.Key(start: TileCoordinate(x: 2, y: 5), goal: TileCoordinate(x: 6, y: 5))
    let path = PathFinder.path(from: key.start, to: key.goal, in: world.roadGraph)
    if let path { cache.store(path, for: key) }
    #expect(cache.lookup(key) != nil)

    // Now remove a road. Generation moves, cache invalidates.
    world.enqueue(.demolish(at: TileCoordinate(x: 4, y: 5)))
    world.tick()
    cache.invalidate(currentGeneration: world.roadGraph.generation)
    #expect(cache.lookup(key) == nil)
}
