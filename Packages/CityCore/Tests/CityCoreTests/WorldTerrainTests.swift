import Foundation
import Testing
@testable import CityCore

// Tests for spec `world-terrain` — every `#### Scenario:` heading from
// openspec/changes/add-mvp-foundation/specs/world-terrain/spec.md maps to
// at least one `@Test("scenario: <lowercased title>")` here.

// MARK: - Deterministic island

@Test("scenario: map is identical across launches")
func scenarioMapIsIdenticalAcrossLaunches() {
    let worldA = World.newGame()
    let worldB = World.newGame()
    #expect(worldA.mapWidth >= 80, "MVP island must be at least 80×80 per spec")
    #expect(worldA.mapHeight >= 80)
    #expect(worldA.terrainGrid == worldB.terrainGrid, "two fresh new games must have byte-identical terrain")
}

@Test("scenario: map persists across save/load")
func scenarioMapPersistsAcrossSaveLoad() throws {
    let original = World.newGame()
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(original)
    let decoded = try decoder.decode(World.self, from: encoded)
    #expect(decoded.terrainGrid == original.terrainGrid)
}

// MARK: - Terrain classification

@Test("scenario: tile has exactly one terrain type")
func scenarioTileHasExactlyOneTerrainType() {
    let world = World.newGame()
    for y in 0 ..< world.mapHeight {
        for x in 0 ..< world.mapWidth {
            let terrainHere = world.terrain(at: TileCoordinate(x: x, y: y))
            #expect(terrainHere != nil, "every in-bounds tile must have a terrain type")
            if let terrainHere {
                #expect(TerrainType.allCases.contains(terrainHere))
            }
        }
    }
}

@Test("scenario: forest tile can be cleared")
func scenarioForestTileCanBeCleared() throws {
    var world = World.newGame()
    let forestTile = try #require(world.firstTile(of: .forest), "fixed island must contain at least one forest tile")
    world.enqueue(.harvestForest(at: forestTile))
    world.tick()
    #expect(world.terrain(at: forestTile) == .grass, "harvested forest must become grass")
}

// MARK: - Build eligibility

@Test("scenario: cannot build on water")
func scenarioCannotBuildOnWater() throws {
    let world = World.newGame()
    let waterTile = try #require(world.firstTile(of: .water), "fixed island must contain water tiles")
    let result = world.canPlace(.house, at: waterTile)
    #expect(result == .rejected(.terrainNotBuildable))
}

@Test("scenario: cannot build on occupied tile")
func scenarioCannotBuildOnOccupiedTile() throws {
    var world = World.newGame()
    let grassTile = try #require(world.firstTile(of: .grass), "fixed island must contain grass tiles")
    let occupant = EntityID(raw: 1)
    world.occupiedTiles[grassTile] = occupant
    let result = world.canPlace(.house, at: grassTile)
    #expect(result == .rejected(.tileOccupied))
}

// MARK: - Coordinate system

@Test("scenario: coordinates are integer")
func scenarioCoordinatesAreInteger() {
    let coord = TileCoordinate(x: 12, y: 34)
    // Int's mirror reports its subject type as Int. Compare by name string
    // because swift-testing's macro cannot bind a metatype to a Bool-shaped
    // operand directly.
    let xType = String(describing: Mirror(reflecting: coord.x).subjectType)
    let yType = String(describing: Mirror(reflecting: coord.y).subjectType)
    #expect(xType == "Int")
    #expect(yType == "Int")
}
