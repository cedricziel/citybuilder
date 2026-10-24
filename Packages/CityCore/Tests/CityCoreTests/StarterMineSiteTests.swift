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

/// Road tiles from `center`'s road ring to its nearest mine site, once Mining is researched; nil
/// beyond `World.starterMineRoadReach`.
private func mineRoadSteps(from center: Building, in world: World) throws -> Int? {
    var probe = world
    probe.research.markResearched(.mining)
    let map = probe.tileToIslandMap()
    let island = try #require(map[center.anchor])
    let steps = probe.roadSteps(fromRingOf: center.anchor, island: island, tileToIsland: map)
    let ring = Set(World.ringSquare(of: center.anchor))
    let mine = BuildingCatalog.spec(for: .mine).footprint
    return map.filter { $0.value == island }.keys.compactMap { corner -> Int? in
        guard !mine.tiles(anchor: corner).contains(where: ring.contains),
              probe.siteRejection(.mine, at: corner, for: center.owner, tileToIsland: map) == nil
        else { return nil }
        return World.sideNeighbours(of: mine, at: corner).compactMap { steps[$0] }.min()
    }.min()
}

private func homeMineRoadSteps(_ world: World) throws -> Int? {
    let center = try #require(world.occupiedTiles[world.camera.centerTile()].flatMap { world.buildings[$0] })
    return try mineRoadSteps(from: center, in: world)
}

@Test("scenario: a mine site lies near every town center", arguments: Array(UInt64(0) ..< 30))
func scenarioAMineSiteLiesNearEveryTownCenter(seed: UInt64) throws {
    for layout in WorldLayout.allCases {
        // Without rivals every town center stays as generation left it, before rival towns build.
        let world = World.newGame(layout: layout, seed: seed, rivals: false)
        for center in world.buildings.values where center.kind == .townCenter {
            #expect(try mineRoadSteps(from: center, in: world) != nil, "\(layout) seed \(seed) town center \(center.id.raw)")
        }
    }
}

@Test("scenario: a far mine site raises a near outcrop")
func scenarioAFarMineSiteRaisesANearOutcrop() throws {
    // Archipelago seed 1's home island holds mine sites only 23 road tiles out.
    let world = World.newGame(layout: .archipelago, seed: 1)
    let generated = ArchipelagoGenerator.generate(seed: 1)
    let raised = (0 ..< world.terrainGrid.count).filter { world.terrainGrid[$0] == .mountain && generated[$0] != .mountain }
        .map { TileCoordinate(x: $0 % world.mapWidth, y: $0 / world.mapWidth) }
    let home = try #require(world.tileToIslandMap()[world.camera.centerTile()])
    let onHome = raised.filter { world.tileToIslandMap()[$0] == home }
    #expect(onHome.count == 9)
    let corner = try #require(onHome.min { ($0.y, $0.x) < ($1.y, $1.x) })
    #expect(Set(onHome) == Set(Footprint(width: 3, height: 3).tiles(anchor: corner)))
    #expect(try homeMineRoadSteps(world) == 6)
}

@Test("scenario: only a missing mine site raises a tile")
func scenarioOnlyAMissingMineSiteRaisesATile() throws {
    // Archipelago seed 9's home town center has a mine site 1 road tile out.
    let world = World.newGame(layout: .archipelago, seed: 9)
    let generated = ArchipelagoGenerator.generate(seed: 9)
    let home = try #require(world.tileToIslandMap()[world.camera.centerTile()])
    let changed = (0 ..< world.terrainGrid.count).filter { index in
        world.terrainGrid[index] == .mountain && generated[index] != .mountain
            && world.tileToIslandMap()[TileCoordinate(x: index % world.mapWidth, y: index / world.mapWidth)] == home
    }
    #expect(changed.isEmpty)
}

@Test("scenario: the outcrop takes the nearest grass square outside the start area")
func nearOutcropTakesTheNearestSquare() throws {
    // A 30×30 grass island with its town center at (2, 2): the start area
    // runs to (12, 12) and the road ring covers (1, 1) to (5, 5).
    var world = World.fixtureWithTerrain(width: 30, height: 30, fill: .grass, seed: 1)
    world.islands = IslandDetector.detectIslands(
        width: 30, height: 30, terrain: world.terrainGrid, mapHeightForClimate: 30, seed: 1
    )
    let map = world.tileToIslandMap()
    let island = try #require(world.islands.first { $0.id == map[TileCoordinate(x: 2, y: 2)] })
    world.raiseStarterMineSite(besideTownCenterAt: TileCoordinate(x: 2, y: 2), island: island, tileToIsland: map)
    let mountains = (0 ..< 900).filter { world.terrainGrid[$0] == .mountain }.map { TileCoordinate(x: $0 % 30, y: $0 / 30) }
    // (12, 1) is 7 road tiles from the ring's (5, 1); (13, 0) is the upper-left square beside it.
    #expect(Set(mountains) == Set(Footprint(width: 3, height: 3).tiles(anchor: TileCoordinate(x: 13, y: 0))))
}

@Test("a candidate that makes no mine site is put back and the next one is tried")
func failedMineSiteCandidateIsPutBack() throws {
    // A 30×30 grass island with its town center at (2, 2), so the start
    // area runs to (12, 12). Buildings fill the band 13–16 around it, so
    // no near outcrop fits and the island-wide raise runs. The mountain at
    // (20, 4) is nearest, but water above and below it leaves no 2×2 for
    // either grass neighbour; the mountain at (22, 10) has room.
    var world = World.fixtureWithTerrain(width: 30, height: 30, fill: .grass, seed: 1)
    for (x, y) in [(20, 4), (22, 10)] {
        world.terrainGrid[y * 30 + x] = .mountain
    }
    for (x, y) in [(19, 3), (20, 3), (21, 3), (19, 5), (20, 5), (21, 5)] {
        world.terrainGrid[y * 30 + x] = .water
    }
    for index in 0 ..< 900 where (13 ... 16).contains(index % 30) || (13 ... 16).contains(index / 30) {
        world.occupiedTiles[TileCoordinate(x: index % 30, y: index / 30)] = EntityID(raw: 999)
    }
    world.islands = IslandDetector.detectIslands(
        width: 30, height: 30, terrain: world.terrainGrid, mapHeightForClimate: 30, seed: 1
    )
    let map = world.tileToIslandMap()
    let island = try #require(world.islands.first { $0.id == map[TileCoordinate(x: 2, y: 2)] })
    world.raiseStarterMineSite(besideTownCenterAt: TileCoordinate(x: 2, y: 2), island: island, tileToIsland: map)
    #expect(world.terrain(at: TileCoordinate(x: 21, y: 4)) == .grass)
    #expect(world.terrain(at: TileCoordinate(x: 19, y: 4)) == .grass)
    #expect(world.terrain(at: TileCoordinate(x: 23, y: 10)) == .mountain)
}
