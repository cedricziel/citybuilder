import Testing
@testable import CityCore

// world-terrain / Starter mine site (openspec/changes/bread-and-tools-reach).

/// Tiles of the island `tile` lies on.
private func islandTiles(of tile: TileCoordinate, in world: World) -> [TileCoordinate] {
    let map = world.tileToIslandMap()
    guard let island = map[tile] else { return [] }
    return map.filter { $0.value == island }.map(\.key)
}

/// True when the owner of `center` could place a mine on its island once
/// Mining is researched.
private func holdsMineSite(_ center: Building, in world: World) -> Bool {
    var probe = world
    probe.research.markResearched(.mining)
    let map = probe.tileToIslandMap()
    return islandTiles(of: center.anchor, in: probe).contains {
        probe.siteRejection(.mine, at: $0, for: center.owner, tileToIsland: map) == nil
    }
}

@Test("scenario: every town center's island has a mine site", arguments: Array(UInt64(0) ..< 50))
func scenarioEveryTownCentersIslandHasAMineSite(seed: UInt64) {
    for layout in WorldLayout.allCases {
        let world = World.newGame(layout: layout, seed: seed)
        // Every town center: the player's home and other islands, and
        // each rival's.
        for center in world.goodsBuffers() where center.kind == .townCenter {
            #expect(holdsMineSite(center, in: world), "\(layout) seed \(seed) town center \(center.id.raw)")
        }
    }
}

/// Mountain tiles on `island`, in the world and in the terrain the
/// generator made before start sites were placed.
private func mountains(onIsland island: IslandID, seed: UInt64) -> (world: Int, generated: Int) {
    let world = World.newGame(layout: .archipelago, seed: seed)
    let generated = ArchipelagoGenerator.generate(seed: seed)
    let tiles = world.tileToIslandMap().filter { $0.value == island }.map(\.key)
    let index = { (tile: TileCoordinate) in tile.y * world.mapWidth + tile.x }
    return (
        tiles.count { world.terrainGrid[index($0)] == .mountain },
        tiles.count { generated[index($0)] == .mountain }
    )
}

@Test("scenario: only a missing mine site raises a tile")
func scenarioOnlyAMissingMineSiteRaisesATile() {
    // Seed 5's island 1, a player town center's, has mountains but no
    // mine site; seed 0's town-center islands all have one.
    let raised = mountains(onIsland: 1, seed: 5)
    #expect(raised.world == raised.generated + 1)
    let world = World.newGame(layout: .archipelago, seed: 0)
    #expect(world.terrainGrid.count { $0 == .mountain } == ArchipelagoGenerator.generate(seed: 0).count { $0 == .mountain })
}

@Test("a candidate that makes no mine site is put back and the next one is tried")
func failedMineSiteCandidateIsPutBack() throws {
    // A 20×20 grass island with its town center at (2, 2), so the start
    // area runs to (12, 12). The mountain at (15, 4) is nearest, but
    // water above and below it leaves no 2×2 for either grass neighbour;
    // the mountain at (17, 12) has room.
    var world = World.fixtureWithTerrain(width: 20, height: 20, fill: .grass, seed: 1)
    for (x, y) in [(15, 4), (17, 12)] {
        world.terrainGrid[y * 20 + x] = .mountain
    }
    for (x, y) in [(14, 3), (15, 3), (16, 3), (14, 5), (15, 5), (16, 5)] {
        world.terrainGrid[y * 20 + x] = .water
    }
    world.islands = IslandDetector.detectIslands(
        width: 20, height: 20, terrain: world.terrainGrid, mapHeightForClimate: 20, seed: 1
    )
    let map = world.tileToIslandMap()
    let island = try #require(world.islands.first { $0.id == map[TileCoordinate(x: 2, y: 2)] })
    world.raiseStarterMineSite(besideTownCenterAt: TileCoordinate(x: 2, y: 2), island: island, tileToIsland: map)
    #expect(world.terrain(at: TileCoordinate(x: 16, y: 4)) == .grass)
    #expect(world.terrain(at: TileCoordinate(x: 14, y: 4)) == .grass)
    #expect(world.terrain(at: TileCoordinate(x: 18, y: 12)) == .mountain)
}
