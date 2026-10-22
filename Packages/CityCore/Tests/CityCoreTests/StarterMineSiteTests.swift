import Testing
@testable import CityCore

// world-terrain / Starter mine site (openspec/changes/bread-and-tools-reach).

/// The player's town center island and the tiles on it.
private func homeIsland(of world: World) -> (id: IslandID, tiles: [TileCoordinate])? {
    let map = world.tileToIslandMap()
    guard let center = world.goodsBuffers(of: .player).first(where: { $0.kind == .townCenter }),
          let island = map[center.anchor]
    else { return nil }
    return (island, map.filter { $0.value == island }.map(\.key))
}

/// True when the player could place a mine somewhere on the home island
/// once Mining is researched.
private func holdsMineSite(_ world: World) -> Bool {
    var probe = world
    probe.research.markResearched(.mining)
    guard let home = homeIsland(of: probe) else { return false }
    let map = probe.tileToIslandMap()
    return home.tiles.contains { probe.siteRejection(.mine, at: $0, for: .player, tileToIsland: map) == nil }
}

@Test("scenario: every home island has a mine site", arguments: Array(UInt64(0) ..< 50))
func scenarioEveryHomeIslandHasAMineSite(seed: UInt64) {
    for layout in WorldLayout.allCases {
        #expect(holdsMineSite(World.newGame(layout: layout, seed: seed)), "\(layout) seed \(seed)")
    }
}

/// Mountain tiles on the home island in the world, and in the terrain
/// the generator made before start sites were placed.
private func homeMountains(seed: UInt64) -> (world: Int, generated: Int) {
    let world = World.newGame(layout: .archipelago, seed: seed)
    let generated = ArchipelagoGenerator.generate(seed: seed)
    guard let home = homeIsland(of: world) else { return (0, 0) }
    let index = { (tile: TileCoordinate) in tile.y * world.mapWidth + tile.x }
    return (
        home.tiles.count { world.terrainGrid[index($0)] == .mountain },
        home.tiles.count { generated[index($0)] == .mountain }
    )
}

@Test("scenario: only a missing mine site raises a tile")
func scenarioOnlyAMissingMineSiteRaisesATile() {
    let raised = homeMountains(seed: 5)
    #expect(raised.world == raised.generated + 1)
    let kept = homeMountains(seed: 0)
    #expect(kept.world == kept.generated)
}
