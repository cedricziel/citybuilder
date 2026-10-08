import Foundation

public extension World {
    /// Constructs a deterministic test fixture world filled with a single
    /// terrain type. Used by unit tests that need a small known map without
    /// invoking the fixed-island generator.
    /// Auto-grants unlimited test material credits so paid placements
    /// succeed without bootstrapping production chains. Tests that need
    /// exact material accounting (see `MaterialPlacementTests`) use
    /// `World.newGame(...)` instead, which carries only the town
    /// center's starter inventory.
    static func fixtureWithTerrain(
        width: Int,
        height: Int,
        fill: TerrainType,
        seed: UInt64
    ) -> World {
        let grid = Array(repeating: fill, count: width * height)
        var world = World(seed: seed, mapWidth: width, mapHeight: height, terrainGrid: grid)
        world.seedUnlimitedTestInventory()
        return world
    }

    /// Constructs a fresh new game with the fixed MVP island terrain
    /// produced by `IslandGenerator`. Identical for every player and every
    /// session per spec `world-terrain` ("Map is identical across launches").
    static func newGame() -> World {
        newGame(layout: .singleIsland, seed: 0)
    }

    /// Constructs a fresh new game with the named topology and seed.
    /// Spec: `world-terrain` / Requirement: World layout.
    static func newGame(layout: WorldLayout, seed: UInt64) -> World {
        let grid: [TerrainType]
        let width: Int
        let height: Int
        switch layout {
        case .singleIsland:
            grid = IslandGenerator.generate()
            width = IslandGenerator.width
            height = IslandGenerator.height
        case .archipelago:
            grid = ArchipelagoGenerator.generate(seed: seed)
            width = ArchipelagoGenerator.width
            height = ArchipelagoGenerator.height
        }
        var world = World(seed: seed, mapWidth: width, mapHeight: height, terrainGrid: grid)
        world.layout = layout
        world.islands = IslandDetector.detectIslands(
            width: width,
            height: height,
            terrain: grid,
            mapHeightForClimate: height,
            seed: seed
        )
        world.seedTownCenters()
        world.research = .initial
        return world
    }

    /// Seed an operational town center on every island that can host
    /// the 3×3 footprint, with the starter inventory of 6 wood +
    /// 5 planks + 2 food. Run once at world-gen; the town center
    /// becomes the bootstrap goods-buffer for the first placements.
    internal mutating func seedTownCenters() {
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        let starter: [(Good, Int)] = [(.wood, 6), (.planks, 5), (.food, 2)]
        for island in islands {
            guard let anchor = findFootprint(footprint, on: island) else { continue }
            let id = EntityID(raw: nextEntityRaw)
            nextEntityRaw &+= 1
            let building = Building(
                id: id,
                kind: .townCenter,
                anchor: anchor,
                state: .operational,
                ticksSincePlacement: 0
            )
            buildings[id] = building
            for tile in footprint.tiles(anchor: anchor) {
                occupiedTiles[tile] = id
            }
            var stockpile = Stockpile(capacity: World.stockpileCapacity(for: .townCenter) ?? 0)
            for (good, amount) in starter {
                _ = stockpile.deposit(good, amount: amount)
            }
            stockpiles[id] = stockpile
        }
    }

    /// Deterministic scan for a buildable footprint of the given size
    /// inside an island's bounding box. Starts from the bounding-box
    /// center and spirals outward in a row-major sweep so the first
    /// hit is reproducible across runs.
    private func findFootprint(_ footprint: Footprint, on island: Island) -> TileCoordinate? {
        let centerX = (island.bounds.minX + island.bounds.maxX) / 2 - footprint.width / 2
        let centerY = (island.bounds.minY + island.bounds.maxY) / 2 - footprint.height / 2
        let maxRadius = max(
            island.bounds.maxX - island.bounds.minX,
            island.bounds.maxY - island.bounds.minY
        )
        for radius in 0 ... maxRadius {
            for deltaY in -radius ... radius {
                for deltaX in -radius ... radius {
                    // Only check the perimeter at each radius to avoid
                    // re-testing interior tiles already covered.
                    if radius > 0, abs(deltaX) != radius, abs(deltaY) != radius {
                        continue
                    }
                    let anchor = TileCoordinate(x: centerX + deltaX, y: centerY + deltaY)
                    if footprintIsBuildable(footprint, at: anchor) {
                        return anchor
                    }
                }
            }
        }
        return nil
    }

    private func footprintIsBuildable(_ footprint: Footprint, at anchor: TileCoordinate) -> Bool {
        for tile in footprint.tiles(anchor: anchor) {
            guard contains(tile) else { return false }
            guard let terrainHere = terrain(at: tile), terrainHere != .water else { return false }
            if occupiedTiles[tile] != nil { return false }
        }
        return true
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

    /// Test helper: grant unlimited construction materials on every
    /// island so test fixtures can place paid buildings via
    /// `.place` commands without first running a production chain.
    /// Implemented as a virtual credit, not a real warehouse — placing
    /// a 3x3 stub building would collide with tight test grids.
    /// canPlace + applyPlace consult this credit in addition to the
    /// real goods-buffer stockpiles.
    mutating func seedUnlimitedTestInventory() {
        testMaterialCredits = [.wood: 999_999, .planks: 999_999, .food: 999_999]
    }
}
