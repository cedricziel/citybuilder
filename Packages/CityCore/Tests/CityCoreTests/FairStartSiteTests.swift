import Foundation
import Testing
@testable import CityCore

// Spec: world-terrain / Fair start sites, Starter grove, Start placement
// independent of difficulty (change fair-start-sites).

// MARK: - Hand-made terrain

/// A square map with a one-tile water border; every land tile starts
/// as `fill`.
private struct TerrainSketch {
    let width: Int
    let height: Int
    var tiles: [TerrainType]

    init(width: Int, height: Int, fill: TerrainType) {
        self.width = width
        self.height = height
        tiles = Array(repeating: .water, count: width * height)
        for y in 1 ..< height - 1 {
            for x in 1 ..< width - 1 {
                tiles[y * width + x] = fill
            }
        }
    }

    /// Land rows where `y % period == 0` become grass, the rest stay as
    /// they are: grass without any 5×5 all-grass square.
    mutating func grassRows(every period: Int) {
        for y in 1 ..< height - 1 where y % period == 0 {
            for x in 1 ..< width - 1 {
                tiles[y * width + x] = .grass
            }
        }
    }

    mutating func paint(_ kind: TerrainType, x xs: ClosedRange<Int>, y ys: ClosedRange<Int>) {
        for y in ys {
            for x in xs {
                tiles[y * width + x] = kind
            }
        }
    }

    /// Grass under a town center anchored at `anchor` and its ring.
    mutating func pocket(at anchor: TileCoordinate) {
        paint(.grass, x: anchor.x - 1 ... anchor.x + 3, y: anchor.y - 1 ... anchor.y + 3)
    }

    /// The terrain with islands detected and nothing placed.
    func pristine() -> World {
        var world = World(seed: 0, mapWidth: width, mapHeight: height, terrainGrid: tiles)
        world.islands = IslandDetector.detectIslands(
            width: width, height: height, terrain: tiles, mapHeightForClimate: height, seed: 0
        )
        return world
    }

    func world() -> World {
        World.generate(layout: .singleIsland, seed: 0, width: width, height: height, terrain: tiles, rivals: false)
    }
}

private func townCenters(in world: World) -> [Building] {
    world.buildings.values.filter { $0.kind == .townCenter }.sorted { $0.id.raw < $1.id.raw }
}

private func target(of world: World) throws -> TileCoordinate {
    try World.startTarget(of: #require(world.islands.first))
}

private func shifted(_ tile: TileCoordinate, _ dx: Int, _ dy: Int) -> TileCoordinate {
    TileCoordinate(x: tile.x + dx, y: tile.y + dy)
}

// MARK: - Fair start sites

@Test("scenario: single-island town center avoids the mountain core")
func scenarioSingleIslandTownCenterAvoidsTheMountainCore() throws {
    let world = World.newGame()
    let center = try #require(townCenters(in: world).first)
    for tile in World.ringSquare(of: center.anchor) {
        #expect(world.terrain(at: tile) == .grass)
    }
    let area = world.startArea(ofTownCenterAt: center.anchor)
    #expect(area.grass >= 150)
    #expect(area.mountain * 4 <= area.tiles)
}

@Test("scenario: town center takes the nearest qualifying site")
func scenarioTownCenterTakesTheNearestQualifyingSite() throws {
    var sketch = TerrainSketch(width: 41, height: 41, fill: .forest)
    sketch.grassRows(every: 2)
    let centre = try target(of: sketch.world())
    let near = shifted(centre, 5, 0)
    let far = shifted(centre, 0, 6)
    sketch.pocket(at: near)
    sketch.pocket(at: far)
    let world = sketch.world()
    #expect(townCenters(in: world).map(\.anchor) == [near])
}

@Test("scenario: ties between equally near sites go to the upper row")
func scenarioTiesBetweenEquallyNearSitesGoToTheUpperRow() throws {
    var sketch = TerrainSketch(width: 41, height: 41, fill: .forest)
    sketch.grassRows(every: 2)
    let centre = try target(of: sketch.world())
    // Both at squared distance 25; each pocket is bounded by forest rows.
    let lower = shifted(centre, -3, 4)
    let upper = shifted(centre, -3, -4)
    sketch.pocket(at: lower)
    sketch.pocket(at: upper)
    let world = sketch.world()
    #expect(townCenters(in: world).map(\.anchor) == [upper])
}

@Test("scenario: fallback takes the grassiest all-grass site")
func scenarioFallbackTakesTheGrassiestAllGrassSite() throws {
    var sketch = TerrainSketch(width: 81, height: 41, fill: .forest)
    sketch.grassRows(every: 3)
    let centre = try target(of: sketch.world())
    let near = shifted(centre, -20, 0)
    let far = shifted(centre, 20, 0)
    sketch.pocket(at: near)
    sketch.pocket(at: far)
    // One extra grass row next to the far pocket, still short of 150.
    let extraRow = far.y - 3
    sketch.paint(.grass, x: far.x - 8 ... far.x + 10, y: extraRow ... extraRow)
    let world = sketch.world()
    let probe = sketch.pristine()
    let nearGrass = probe.startArea(ofTownCenterAt: near).grass
    let farGrass = probe.startArea(ofTownCenterAt: far).grass
    #expect(farGrass > nearGrass)
    #expect(farGrass < 150)
    let island = try #require(probe.islands.first)
    let site = try #require(probe.townCenterSite(on: island, tileToIsland: probe.tileToIslandMap()))
    #expect(site.rule == .grassiest)
    #expect(townCenters(in: world).map(\.anchor) == [far])
}

@Test("scenario: fallback without any all-grass square keeps the old rule")
func scenarioFallbackWithoutAnyAllGrassSquareKeepsTheOldRule() throws {
    let sketch = TerrainSketch(width: 31, height: 31, fill: .forest)
    let world = sketch.world()
    let centre = try target(of: world)
    #expect(townCenters(in: world).map(\.anchor) == [centre])
    let island = try #require(world.islands.first)
    let site = try #require(sketch.world().townCenterSite(on: island, tileToIsland: world.tileToIslandMap()))
    #expect(site.rule == .anyLand)
}

// MARK: - Starter grove

@Test("scenario: grove gives a hut site with 32 trees")
func scenarioGroveGivesAHutSiteWith32Trees() {
    let world = World.newGame(layout: .archipelago, seed: 0)
    let centers = townCenters(in: world)
    #expect(centers.count == world.islands.count)
    for center in centers {
        #expect(world.startArea(ofTownCenterAt: center.anchor).hutSiteTrees == 32)
    }
}

@Test("scenario: grove stays off the town center ring")
func scenarioGroveStaysOffTheTownCenterRing() {
    for world in [World.newGame(), World.newGame(layout: .archipelago, seed: 3)] {
        for center in townCenters(in: world) {
            for tile in World.ringSquare(of: center.anchor) {
                #expect(world.terrain(at: tile) == .grass, "\(tile) under or beside the town center is not grass")
            }
        }
    }
}

@Test("scenario: grove leaves the island list unchanged")
func scenarioGroveLeavesTheIslandListUnchanged() {
    let seed: UInt64 = 5
    let world = World.newGame(layout: .archipelago, seed: seed)
    let generated = ArchipelagoGenerator.generate(seed: seed)
    #expect(world.terrainGrid != generated, "groves must have changed some terrain")
    let detected = IslandDetector.detectIslands(
        width: world.mapWidth, height: world.mapHeight, terrain: generated,
        mapHeightForClimate: world.mapHeight, seed: seed
    )
    #expect(world.islands == detected)
}

@Test("scenario: no room for a grove plants none")
func scenarioNoRoomForAGrovePlantsNone() {
    // 7×7 land: room for the 5×5 town center square, not for a 6×6 grove.
    let sketch = TerrainSketch(width: 9, height: 9, fill: .grass)
    let world = sketch.world()
    #expect(townCenters(in: world).count == 1)
    #expect(world.terrainGrid == sketch.tiles)
}

// MARK: - Independence from difficulty and rivals

@Test("scenario: difficulty does not move town centers")
func scenarioDifficultyDoesNotMoveTownCenters() {
    let worlds = Difficulty.allCases.map { World.newGame(layout: .archipelago, seed: 11, difficulty: $0) }
    let anchors = worlds.map { townCenters(in: $0).map(\.anchor) }
    for world in worlds.dropFirst() {
        #expect(world.terrainGrid == worlds[0].terrainGrid)
    }
    for other in anchors.dropFirst() {
        #expect(other == anchors[0])
    }
}

@Test("scenario: rivals get the same start rule as the player")
func scenarioRivalsGetTheSameStartRuleAsThePlayer() throws {
    let withRivals = World.newGame(layout: .archipelago, seed: 4, difficulty: .hard, rivals: true)
    let without = World.newGame(layout: .archipelago, seed: 4, difficulty: .hard, rivals: false)
    let map = without.tileToIslandMap()
    #expect(!withRivals.rivals.isEmpty)
    for rival in withRivals.rivals {
        let center = try #require(withRivals.buildings[rival.townCenterID])
        let same = try #require(without.townCenter(onIsland: rival.islandID, tileToIsland: map))
        #expect(center.anchor == same.anchor)
        #expect(withRivals.startArea(ofTownCenterAt: center.anchor).isFair)
    }
}

// MARK: - Acceptance: fairness across seeds

private struct SweepRow: Sendable {
    let fair: Int
    let trees: [Int]
    let fallbacks: Int

    var starts: Int {
        trees.count
    }
}

/// Measures every town center of the world, and checks the rule that
/// placed it against the generator's terrain before any placement.
private func sweep(_ world: World, generated: [TerrainType]) -> SweepRow {
    var pristine = World(seed: world.seed, mapWidth: world.mapWidth, mapHeight: world.mapHeight, terrainGrid: generated)
    pristine.islands = world.islands
    let map = pristine.tileToIslandMap()
    var fair = 0
    var trees: [Int] = []
    var fallbacks = 0
    for center in townCenters(in: world) {
        let area = world.startArea(ofTownCenterAt: center.anchor)
        if area.isFair { fair += 1 }
        trees.append(area.hutSiteTrees)
    }
    for island in pristine.islands where pristine.townCenterSite(on: island, tileToIsland: map)?.rule != .fair {
        fallbacks += 1
    }
    return SweepRow(fair: fair, trees: trees, fallbacks: fallbacks)
}

@Test("scenario: every start is fair across seeds", .serialized, arguments: Array(UInt64(0) ..< 50))
func scenarioEveryStartIsFairAcrossSeeds(seed: UInt64) {
    let generated = ArchipelagoGenerator.generate(seed: seed)
    var terrains: [[TerrainType]] = []
    var rows: [SweepRow] = []
    for difficulty in Difficulty.allCases {
        let world = World.newGame(layout: .archipelago, seed: seed, difficulty: difficulty)
        terrains.append(world.terrainGrid)
        rows.append(sweep(world, generated: generated))
    }
    if seed == 0 {
        let single = World.newGame()
        rows.append(sweep(single, generated: IslandGenerator.generate()))
        let center = townCenters(in: single).first
        print("fair-start single island: TC \(center.map { "(\($0.anchor.x),\($0.anchor.y))" } ?? "none"), "
            + "\(center.map { single.startArea(ofTownCenterAt: $0.anchor) }.map { "\($0)" } ?? "")")
    }
    for row in rows {
        #expect(row.fair == row.starts, "seed \(seed): \(row.starts - row.fair) unfair starts")
        #expect(row.fallbacks == 0, "seed \(seed): \(row.fallbacks) fallback placements")
    }
    #expect(Set(terrains).count == 1, "seed \(seed): terrain differs across difficulties")
    let trees = rows.flatMap(\.trees).sorted()
    print("fair-start seed \(seed): \(rows.map(\.fair).reduce(0, +))/\(rows.map(\.starts).reduce(0, +)) fair, "
        + "hut site trees \(trees.first ?? 0)–\(trees.last ?? 0)")
}

// MARK: - Starter road

@Test("scenario: starter road ring is complete on every fair start", .serialized, arguments: Array(UInt64(0) ..< 50))
func scenarioStarterRoadRingIsCompleteOnEveryFairStart(seed: UInt64) {
    var worlds = [World.newGame(layout: .archipelago, seed: seed)]
    if seed == 0 { worlds.append(World.newGame()) }
    for world in worlds {
        for center in townCenters(in: world) where center.owner == .player {
            let ring = World.ringSquare(of: center.anchor).filter { world.occupiedTiles[$0] != center.id }
            #expect(ring.count == 16)
            for tile in ring {
                let road = world.occupiedTiles[tile].flatMap { world.buildings[$0] }
                #expect(road?.kind == .road && road?.owner == .player, "seed \(seed): \(tile) is not player road")
            }
        }
    }
}

// MARK: - Camera

@Test("scenario: camera starts on the player's town center")
func scenarioCameraStartsOnThePlayersTownCenter() throws {
    for world in [World.newGame(), World.newGame(layout: .archipelago, seed: 7)] {
        let map = world.tileToIslandMap()
        let home = map[TileCoordinate(x: world.mapWidth / 2, y: world.mapHeight / 2)]
        let center = try #require(townCenters(in: world).first { $0.owner == .player && map[$0.anchor] == home })
        let footprint = BuildingCatalog.spec(for: .townCenter).footprint
        #expect(footprint.tiles(anchor: center.anchor).contains(world.camera.centerTile()))
    }
}
