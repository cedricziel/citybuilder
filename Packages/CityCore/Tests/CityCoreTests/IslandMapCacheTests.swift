import Foundation
import Testing
@testable import CityCore

// Worlds that share island shapes must keep hitting the island map
// cache by buffer identity, without full-map comparisons.

private func lookUp(_ cache: IslandMapCache, _ world: World) -> [TileCoordinate: IslandID] {
    cache.map(width: world.mapWidth, height: world.mapHeight, terrain: world.terrainGrid)
}

@Test("worlds sharing island shapes keep hitting the cache by buffer")
func worldsSharingIslandShapesKeepHittingTheCacheByBuffer() {
    let cache = IslandMapCache()
    let first = World.newGame(layout: .archipelago, seed: 0)
    let second = World.newGame(layout: .archipelago, seed: 1)
    #expect(lookUp(cache, first) == lookUp(cache, second))
    let comparisons = cache.maskComparisons
    for _ in 0 ..< 10 {
        _ = lookUp(cache, first)
        _ = lookUp(cache, second)
    }
    #expect(cache.maskComparisons == comparisons)
}
