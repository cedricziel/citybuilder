import Foundation

/// Terrain directives: deterministic terrain changes after generation.
/// Spec: `world-terrain` / Terrain directives (`add-campaigns` D6).
extension World {
    /// Runs after every town center, starter grove and starter mine site
    /// is placed, and before rivals are seated and starter roads laid. The
    /// island list never changes: directives only swap land types.
    mutating func applyTerrainDirectives(_ directives: [TerrainDirective]) {
        for directive in directives {
            let map = tileToIslandMap()
            switch directive {
            case let .thinForest(ref, keep):
                island(ref, in: map).map { thinForest(on: $0, keepPercent: keep, map: map) }
            case let .pushMineOut(radius):
                pushMineOut(radius: radius, map: map)
            case let .noMountains(ref):
                island(ref, in: map).map { clearMountains(on: $0, map: map) { _ in true } }
            case let .raiseMineSite(ref):
                guard let island = island(ref, in: map), let center = townCenter(onIsland: island.id, tileToIsland: map) else {
                    continue
                }
                raiseStarterMineSite(besideTownCenterAt: center.anchor, island: island, tileToIsland: map)
            }
        }
    }

    private func island(_ ref: IslandRef, in map: [TileCoordinate: IslandID]) -> Island? {
        let home = homeIslandID(in: map)
        switch ref {
        case .home:
            return islands.first { $0.id == home }
        case let .other(rank):
            let others = otherIslandsBySize(home: home)
            return others.indices.contains(rank - 1) ? others[rank - 1] : nil
        }
    }

    /// A forest tile outside the starter grove stays forest only when the
    /// tile's hash, modulo 100, is below `keepPercent`.
    private mutating func thinForest(on island: Island, keepPercent: Int, map: [TileCoordinate: IslandID]) {
        let grove = Set(townCenter(onIsland: island.id, tileToIsland: map)
            .flatMap { starterGroveTiles(of: $0.anchor, island: island.id, map: map) } ?? [])
        for tile in islandTiles(of: island, tileToIsland: map) where terrain(at: tile) == .forest && !grove.contains(tile) {
            if Self.directiveHash(seed: seed, tile: tile) % 100 >= UInt64(keepPercent) {
                terrainGrid[tile.y * mapWidth + tile.x] = .grass
            }
        }
    }

    /// The starter grove's tiles beside the town center at `anchor`: the
    /// corner the grove rule picks, which planting never changes.
    func starterGroveTiles(of anchor: TileCoordinate, island: IslandID, map: [TileCoordinate: IslandID]) -> [TileCoordinate]? {
        starterGroveCorner(besideTownCenterAt: anchor, island: island, tileToIsland: map).map {
            Footprint(width: Self.groveSide, height: Self.groveSide).tiles(anchor: $0)
        }
    }

    private mutating func clearMountains(on island: Island, map: [TileCoordinate: IslandID], where clear: (TileCoordinate) -> Bool) {
        for tile in islandTiles(of: island, tileToIsland: map) where terrain(at: tile) == .mountain && clear(tile) {
            terrainGrid[tile.y * mapWidth + tile.x] = .grass
        }
    }

    /// Clears every mountain within `radius` (Chebyshev) of the home town
    /// center, then raises an outcrop farther out when no mine site is
    /// left on the home island.
    private mutating func pushMineOut(radius: Int, map: [TileCoordinate: IslandID]) {
        guard let home = homeIslandID(in: map), let island = islands.first(where: { $0.id == home }),
              let anchor = townCenter(onIsland: home, tileToIsland: map)?.anchor
        else { return }
        let distance = { (tile: TileCoordinate) in max(abs(tile.x - anchor.x), abs(tile.y - anchor.y)) }
        clearMountains(on: island, map: map) { distance($0) <= radius }
        let islandTiles = islandTiles(of: island, tileToIsland: map)
        var probe = self
        probe.research.markResearched(.mining)
        guard !islandTiles.contains(where: { probe.isMineSite($0, map: map) }) else { return }
        let occupied = occupiedTiles
        _ = raiseNearMineOutcrop(
            among: islandTiles,
            raisable: { distance($0) > radius && occupied[$0] == nil },
            roads: Dictionary(uniqueKeysWithValues: islandTiles.map { ($0, distance($0)) }),
            probe: probe,
            tileToIsland: map
        )
    }

    /// A 2×2 square at `corner` where a mine fits.
    func isMineSite(_ corner: TileCoordinate, map: [TileCoordinate: IslandID]) -> Bool {
        siteRejection(.mine, at: corner, for: .player, tileToIsland: map) == nil
    }

    /// A SplitMix mix of the seed and the tile: the same on every platform.
    static func directiveHash(seed: UInt64, tile: TileCoordinate) -> UInt64 {
        var value = seed &+ 0x9E37_79B9_7F4A_7C15
        value &+= UInt64(bitPattern: Int64(tile.x)) &* 0xBF58_476D_1CE4_E5B9
        value &+= UInt64(bitPattern: Int64(tile.y)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return value
    }
}
