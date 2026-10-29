import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-campaigns (world-terrain / Terrain
// directives).

private func homeAnchor(_ world: World) throws -> TileCoordinate {
    let map = world.tileToIslandMap()
    let home = try #require(world.homeIslandID(in: map))
    let center = try #require(world.buildings.values
        .filter { $0.kind == .townCenter && $0.owner == .player && map[$0.anchor] == home }
        .min { $0.id.raw < $1.id.raw })
    return center.anchor
}

private func tiles(on island: IslandID, of world: World, where kind: TerrainType) -> [TileCoordinate] {
    let map = world.tileToIslandMap()
    return world.terrainGrid.indices.compactMap { index in
        let tile = TileCoordinate(x: index % world.mapWidth, y: index / world.mapWidth)
        return world.terrainGrid[index] == kind && map[tile] == island ? tile : nil
    }
}

private func mineSites(on island: IslandID, of world: World) -> [TileCoordinate] {
    var probe = world
    probe.research.markResearched(.mining)
    let map = world.tileToIslandMap()
    return world.terrainGrid.indices.compactMap { index in
        let tile = TileCoordinate(x: index % world.mapWidth, y: index / world.mapWidth)
        return map[tile] == island && probe.isMineSite(tile, map: map) ? tile : nil
    }
}

@Test("scenario: no directives leaves terrain unchanged")
func scenarioNoDirectivesLeavesTerrainUnchanged() {
    let plain = World.newGame(layout: .archipelago, seed: 7)
    let empty = World.newGame(layout: .archipelago, seed: 7, directives: [])
    #expect(plain.terrainGrid == empty.terrainGrid)
    #expect(plain == empty)
}

@Test("scenario: thin forest keeps about the share asked")
func scenarioThinForestKeepsAboutTheShareAsked() throws {
    let before = World.newGame(layout: .archipelago, seed: 3)
    let world = World.newGame(layout: .archipelago, seed: 3, directives: [.thinForest(.home, keepPercent: 25)])
    let map = world.tileToIslandMap()
    let home = try #require(world.homeIslandID(in: map))
    let anchor = try homeAnchor(world)
    let corner = try #require(before.starterGroveCorner(besideTownCenterAt: anchor, island: home, tileToIsland: map))
    let grove = Set(Footprint(width: World.groveSide, height: World.groveSide).tiles(anchor: corner))
    let groveForest = grove.filter { before.terrain(at: $0) == .forest }
    #expect(!groveForest.isEmpty)
    #expect(groveForest.allSatisfy { world.terrain(at: $0) == .forest })
    let wild = tiles(on: home, of: before, where: .forest).filter { !grove.contains($0) }
    let kept = wild.filter { world.terrain(at: $0) == .forest }
    #expect(kept.allSatisfy { World.directiveHash(seed: 3, tile: $0) % 100 < 25 })
    let share = kept.count * 100 / max(wild.count, 1)
    #expect((20 ... 30).contains(share), "kept \(share)%")
}

@Test("scenario: thin forest is deterministic")
func scenarioThinForestIsDeterministic() {
    let directives: [TerrainDirective] = [.thinForest(.home, keepPercent: 15), .thinForest(.other(rank: 1), keepPercent: 50)]
    let first = World.newGame(layout: .archipelago, seed: 11, directives: directives)
    let second = World.newGame(layout: .archipelago, seed: 11, directives: directives)
    #expect(first.terrainGrid == second.terrainGrid)
}

@Test("scenario: pushing the mine out")
func scenarioPushingTheMineOut() throws {
    let world = World.newGame(layout: .archipelago, seed: 303, directives: [.pushMineOut(radius: 16)])
    let anchor = try homeAnchor(world)
    let home = try #require(world.homeIslandID(in: world.tileToIslandMap()))
    let near = tiles(on: home, of: world, where: .mountain).filter { max(abs($0.x - anchor.x), abs($0.y - anchor.y)) <= 16 }
    #expect(near.isEmpty)
    let sites = mineSites(on: home, of: world)
    #expect(!sites.isEmpty)
    #expect(sites.allSatisfy { max(abs($0.x - anchor.x), abs($0.y - anchor.y)) > 16 })
}

@Test("pushing the mine out raises a site when none is left, clear of the start area and grove")
func pushingTheMineOutRaisesASiteWhenNoneIsLeft() throws {
    for seed: UInt64 in [303, 5, 17] {
        let before = World.newGame(layout: .archipelago, seed: seed, directives: [.noMountains(.home)])
        let world = World.newGame(layout: .archipelago, seed: seed, directives: [.noMountains(.home), .pushMineOut(radius: 8)])
        let map = world.tileToIslandMap()
        let anchor = try homeAnchor(world)
        let home = try #require(world.homeIslandID(in: map))
        let sites = mineSites(on: home, of: world)
        #expect(!sites.isEmpty, "seed \(seed)")
        #expect(sites.allSatisfy { max(abs($0.x - anchor.x), abs($0.y - anchor.y)) > 8 })
        let raised = tiles(on: home, of: world, where: .mountain)
        let (xs, ys) = world.startBounds(ofTownCenterAt: anchor)
        let corner = try #require(before.starterGroveCorner(besideTownCenterAt: anchor, island: home, tileToIsland: map))
        let kept = Set(World.ringSquare(of: anchor) + Footprint(width: World.groveSide, height: World.groveSide).tiles(anchor: corner))
        let intruders = raised.filter { kept.contains($0) || (xs.contains($0.x) && ys.contains($0.y)) }
        #expect(intruders.isEmpty, "seed \(seed): \(intruders)")
    }
}

@Test("scenario: no mountains removes the home mine site")
func scenarioNoMountainsRemovesTheHomeMineSite() throws {
    let world = World.newGame(layout: .archipelago, seed: 5, directives: [.noMountains(.home)])
    let home = try #require(world.homeIslandID(in: world.tileToIslandMap()))
    #expect(tiles(on: home, of: world, where: .mountain).isEmpty)
    #expect(mineSites(on: home, of: world).isEmpty)
}

@Test("scenario: raising a mine site on another island")
func scenarioRaisingAMineSiteOnAnotherIsland() throws {
    let world = World.newGame(
        layout: .archipelago, seed: 5, rivals: false,
        directives: [.noMountains(.home), .noMountains(.other(rank: 4)), .raiseMineSite(.other(rank: 4))]
    )
    let fourth = try #require(world.otherIslandsBySize(home: world.homeIslandID(in: world.tileToIslandMap())).dropFirst(3).first)
    #expect(!mineSites(on: fourth.id, of: world).isEmpty)
    let missing = World.newGame(layout: .archipelago, seed: 5, directives: [.raiseMineSite(.other(rank: 9))])
    #expect(missing.terrainGrid == World.newGame(layout: .archipelago, seed: 5).terrainGrid)
}

@Test("scenario: directives leave the island list alone")
func scenarioDirectivesLeaveTheIslandListAlone() {
    let plain = World.newGame(layout: .archipelago, seed: 21)
    let changed = World.newGame(layout: .archipelago, seed: 21, directives: [
        .thinForest(.home, keepPercent: 10), .pushMineOut(radius: 16), .noMountains(.other(rank: 2)), .raiseMineSite(.other(rank: 2))
    ])
    #expect(changed.islands == plain.islands)
    #expect(changed.terrainGrid != plain.terrainGrid)
}
