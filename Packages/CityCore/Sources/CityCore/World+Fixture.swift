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
    static func newGame(
        layout: WorldLayout,
        seed: UInt64,
        culture: Culture = .northernEuropean,
        age: Age = .medieval,
        difficulty: Difficulty = .normal,
        rivals: Bool = true
    ) -> World {
        let (terrain, width, height) = switch layout {
        case .singleIsland:
            (IslandGenerator.generate(), IslandGenerator.width, IslandGenerator.height)
        case .archipelago:
            (ArchipelagoGenerator.generate(seed: seed), ArchipelagoGenerator.width, ArchipelagoGenerator.height)
        }
        return generate(
            layout: layout, seed: seed, width: width, height: height, terrain: terrain,
            culture: culture, age: age, difficulty: difficulty, rivals: rivals
        )
    }

    /// A new game on the given generator terrain: islands, town centers
    /// with their starter groves, rivals and starter roads. Tests pass
    /// hand-made terrain here.
    internal static func generate(
        layout: WorldLayout,
        seed: UInt64,
        width: Int,
        height: Int,
        terrain grid: [TerrainType],
        culture: Culture = .northernEuropean,
        age: Age = .medieval,
        difficulty: Difficulty = .normal,
        rivals: Bool = true
    ) -> World {
        var world = World(seed: seed, mapWidth: width, mapHeight: height, terrainGrid: grid)
        world.layout = layout
        world.islands = IslandDetector.detectIslands(
            width: width,
            height: height,
            terrain: grid,
            mapHeightForClimate: height,
            seed: seed
        )
        world.difficulty = difficulty
        world.economy.balance = difficulty.startingBalance
        world.seedTownCenters()
        world.research = initialResearch(for: age)
        world.calendar = CalendarState(startYear: age.startYear, isActive: true)
        world.culture = culture
        world.age = age
        if layout == .archipelago, rivals {
            world.seedRivals()
        }
        world.seedStarterRoads()
        world.centerCameraOnHomeTownCenter()
        return world
    }

    /// Seed an operational town center on every island that can host
    /// the 3×3 footprint, on a fair start site with a starter grove
    /// beside it, with the difficulty's starter inventory. Run once at
    /// world-gen, before rivals are seated, so every island gets the
    /// same rule. Spec: `world-terrain` / Fair start sites, Starter grove.
    internal mutating func seedTownCenters() {
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        let starter = difficulty.starterStock
        let tileToIsland = tileToIslandMap()
        for island in islands {
            guard let anchor = townCenterSite(on: island, tileToIsland: tileToIsland)?.anchor else { continue }
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
            var stockpile = World.newStockpile(for: .townCenter) ?? Stockpile(capacity: 0)
            for (good, amount) in starter {
                _ = stockpile.deposit(good, amount: amount)
            }
            stockpiles[id] = stockpile
            plantStarterGrove(besideTownCenterAt: anchor, island: island.id, tileToIsland: tileToIsland)
            raiseStarterMineSite(besideTownCenterAt: anchor, island: island, tileToIsland: tileToIsland)
        }
    }

    /// Ring each player town center with free road so the first
    /// buildings can reach its goods. Rivals lay their own grid. Spec:
    /// `buildings-and-construction` / Town center starter road.
    internal mutating func seedStarterRoads() {
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        let centers = buildings.values
            .filter { $0.kind == .townCenter && $0.owner == .player }
            .sorted { $0.id.raw < $1.id.raw }
        for center in centers {
            let anchor = center.anchor
            for y in anchor.y - 1 ... anchor.y + footprint.height {
                for x in anchor.x - 1 ... anchor.x + footprint.width {
                    let inside = x >= anchor.x && x < anchor.x + footprint.width
                        && y >= anchor.y && y < anchor.y + footprint.height
                    let tile = TileCoordinate(x: x, y: y)
                    guard !inside, contains(tile), terrain(at: tile) != .water, occupiedTiles[tile] == nil
                    else { continue }
                    let id = EntityID(raw: nextEntityRaw)
                    nextEntityRaw &+= 1
                    buildings[id] = Building(id: id, kind: .road, anchor: tile, state: .operational, ticksSincePlacement: 0)
                    occupiedTiles[tile] = id
                    roadGraph.addRoad(at: tile)
                }
            }
        }
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

    /// A short grain chain on a grass strip, placed by command: two
    /// grain farms, a windmill, a bakery and a warehouse along one
    /// road. Ticked, it sends grain and flour straight from producer to
    /// consumer, so the determinism gate covers those hops.
    static func chainFixture() -> World {
        var world = fixtureWithTerrain(width: 24, height: 6, fill: .grass, seed: 0xC4A1)
        world.seedTestFunds()
        for x in 0 ..< 24 {
            world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 3)))
        }
        let chain: [(BuildingKind, TileCoordinate)] = [
            (.grainFarm, TileCoordinate(x: 0, y: 1)), (.grainFarm, TileCoordinate(x: 3, y: 1)),
            (.windmill, TileCoordinate(x: 7, y: 1)), (.bakery, TileCoordinate(x: 11, y: 1)),
            (.warehouse, TileCoordinate(x: 16, y: 0))
        ]
        for (kind, anchor) in chain {
            world.enqueue(.place(kind, at: anchor))
        }
        return world
    }

    /// Test helper: a treasury deep enough that a seeded town's upkeep never bankrupts it, so art
    /// reviews screenshot the town rather than the bankruptcy banner.
    mutating func seedTestFunds(_ amount: Int64 = 1_000_000) {
        economy.balance = amount
    }
}

public extension World {
    /// A new game set up by a built-in scenario: its age, difficulty,
    /// goals and, when it has one, its layout. Rivals are always on.
    /// Spec: `difficulty-and-goals` / Built-in scenarios.
    static func newGame(layout: WorldLayout, seed: UInt64, culture: Culture, scenario: Scenario) -> World {
        var world = newGame(
            layout: scenario.requiredLayout ?? layout, seed: seed, culture: culture,
            age: scenario.age, difficulty: scenario.difficulty, rivals: true
        )
        world.goals = scenario.goals.map { GoalState(goal: $0) }
        return world
    }
}
