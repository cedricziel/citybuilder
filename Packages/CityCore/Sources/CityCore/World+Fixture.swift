import Foundation

public extension World {
    /// Constructs a deterministic test fixture world filled with a single
    /// terrain type. Used by unit tests that need a small known map without
    /// invoking the fixed-island generator.
    static func fixtureWithTerrain(
        width: Int,
        height: Int,
        fill: TerrainType,
        seed: UInt64
    ) -> World {
        let grid = Array(repeating: fill, count: width * height)
        return World(seed: seed, mapWidth: width, mapHeight: height, terrainGrid: grid)
    }

    /// Constructs a fresh new game with the fixed MVP island terrain.
    ///
    /// M1 STUB: returns an empty world (mapWidth = 0) until the fixed-island
    /// generator lands in task 2.5. Tests asserting island properties will
    /// stay red until then.
    static func newGame() -> World {
        World(seed: 0)
    }

    /// First in-bounds tile (row-major scan) whose terrain matches `kind`.
    /// Returns nil if no such tile exists — including when the world has
    /// no terrain at all (the M1 stub state).
    func firstTile(of kind: TerrainType) -> TileCoordinate? {
        for y in 0 ..< mapHeight {
            for x in 0 ..< mapWidth where terrainGrid[y * mapWidth + x] == kind {
                return TileCoordinate(x: x, y: y)
            }
        }
        return nil
    }
}
