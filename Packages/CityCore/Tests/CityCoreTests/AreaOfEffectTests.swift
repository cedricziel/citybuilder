import Testing
@testable import CityCore

// add-areas-of-effect / rendering-2_5d: Areas of effect while placing and selecting.

private func world(_ fill: TerrainType = .grass, width: Int = 16, height: Int = 16) -> World {
    World.fixtureWithTerrain(width: width, height: height, fill: fill, seed: 1)
}

private func set(_ terrain: TerrainType, at tiles: [TileCoordinate], in world: inout World) {
    for tile in tiles {
        world.terrainGrid[tile.y * world.mapWidth + tile.x] = terrain
    }
}

private func tiles(x: ClosedRange<Int>, y: ClosedRange<Int>) -> Set<TileCoordinate> {
    Set(y.flatMap { row in x.map { TileCoordinate(x: $0, y: row) } })
}

@Test("scenario: placing a hut outlines its catchment and lists its trees")
func hutAreaIsItsCatchment() throws {
    var world = world()
    let trees = [TileCoordinate(x: 2, y: 2), TileCoordinate(x: 7, y: 7), TileCoordinate(x: 4, y: 4), TileCoordinate(x: 9, y: 4)]
    set(.forest, at: trees, in: &world)
    let area = try #require(world.areaOfEffect(of: .lumberjackHut, at: TileCoordinate(x: 4, y: 4), placing: true))
    #expect(area.tiles == tiles(x: 2 ... 7, y: 2 ... 7))
    // (4, 4) lies under the plot and (9, 4) beyond the reach.
    #expect(area.targets == [TileCoordinate(x: 2, y: 2), TileCoordinate(x: 7, y: 7)])
    #expect(area.count == 2)
}

@Test("scenario: a forester's targets are its open grass")
func foresterTargetsOpenGrass() throws {
    var world = world(.forest)
    let grass = [TileCoordinate(x: 3, y: 3), TileCoordinate(x: 7, y: 2), TileCoordinate(x: 12, y: 12)]
    set(.grass, at: grass, in: &world)
    let area = try #require(world.areaOfEffect(of: .forester, at: TileCoordinate(x: 4, y: 4), placing: true))
    #expect(area.targets == [TileCoordinate(x: 7, y: 2), TileCoordinate(x: 3, y: 3)])
    #expect(area.count == 2)
}

@Test("scenario: the catchment is clipped to the map")
func catchmentStaysOnTheMap() throws {
    let world = world()
    let area = try #require(world.areaOfEffect(of: .lumberjackHut, at: TileCoordinate(x: 0, y: 0), placing: true))
    #expect(area.tiles == tiles(x: 0 ... 3, y: 0 ... 3))
}

@Test("scenario: placing a mine shows the valid sites nearby")
func mineAreaIsTheValidSitesNearby() throws {
    var world = world()
    world.research.markResearched(.mining)
    // A 3 by 2 patch of rock: a mine needs 2 mountain tiles under its plot.
    set(.mountain, at: Array(tiles(x: 6 ... 8, y: 6 ... 7)), in: &world)
    // A patch too far from the cursor to count.
    set(.mountain, at: Array(tiles(x: 14 ... 15, y: 14 ... 15)), in: &world)
    let area = try #require(world.areaOfEffect(of: .mine, at: TileCoordinate(x: 6, y: 6), placing: true))
    let near = area.tiles.allSatisfy { max(abs($0.x - 7), abs($0.y - 7)) <= 3 }
    #expect(near)
    #expect(area.tiles.isSuperset(of: tiles(x: 6 ... 8, y: 6 ... 7)))
    #expect(!area.tiles.contains(TileCoordinate(x: 14, y: 14)))
    // Its targets are the rock of those sites, row-major.
    #expect(area.targets == Array(tiles(x: 6 ... 8, y: 6 ... 7)).sorted { ($0.y, $0.x) < ($1.y, $1.x) })
    // The cursor's own plot is a site with 4 rock tiles.
    #expect(area.count == 4)
}

@Test("scenario: a mine plot off the rock has no count")
func mineOffTheRockHasNoCount() throws {
    var world = world()
    world.research.markResearched(.mining)
    set(.mountain, at: Array(tiles(x: 6 ... 8, y: 6 ... 7)), in: &world)
    let area = try #require(world.areaOfEffect(of: .mine, at: TileCoordinate(x: 2, y: 2), placing: true))
    #expect(area.count == nil)
    #expect(!area.tiles.isEmpty)
}

@Test("scenario: mine sites ignore missing materials")
func mineSitesIgnoreMaterials() throws {
    // No test inventory: the island holds none of a mine's materials.
    var world = World(seed: 1, mapWidth: 16, mapHeight: 16, terrainGrid: Array(repeating: .grass, count: 256))
    world.research.markResearched(.mining)
    set(.mountain, at: Array(tiles(x: 6 ... 8, y: 6 ... 7)), in: &world)
    #expect(world.canPlace(.mine, at: TileCoordinate(x: 6, y: 6)) != .allowed)
    let area = try #require(world.areaOfEffect(of: .mine, at: TileCoordinate(x: 6, y: 6), placing: true))
    #expect(area.count == 4)
}

@Test("scenario: other kinds and a selected mine have no area")
func noAreaWithoutAReach() {
    var world = world()
    world.research.markResearched(.mining)
    set(.mountain, at: Array(tiles(x: 6 ... 8, y: 6 ... 7)), in: &world)
    #expect(world.areaOfEffect(of: .house, at: TileCoordinate(x: 4, y: 4), placing: true) == nil)
    #expect(world.areaOfEffect(of: .mine, at: TileCoordinate(x: 6, y: 6), placing: false) == nil)
}

@Test("scenario: the query leaves the world unchanged")
func areaQueryIsReadOnly() {
    var world = world()
    set(.forest, at: [TileCoordinate(x: 2, y: 2)], in: &world)
    let before = world
    _ = world.areaOfEffect(of: .lumberjackHut, at: TileCoordinate(x: 4, y: 4), placing: true)
    _ = world.areaOfEffect(of: .mine, at: TileCoordinate(x: 4, y: 4), placing: true)
    #expect(world == before)
}
