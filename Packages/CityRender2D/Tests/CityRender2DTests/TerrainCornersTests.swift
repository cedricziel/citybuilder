import CityCore
import Testing
@testable import CityRender2D

/// rendering-2_5d: Terrain transitions from corner terrain (replace-generative-sprites-with-isokit, design D6).
struct TerrainCornersTests {
    /// A map from rows of characters: g grass, b beach, w water, f forest, m mountain. Row = y.
    private func map(_ rows: [String]) -> (TileCoordinate) -> TerrainType? {
        let grid = rows.map { Array($0) }
        return { coord in
            guard coord.y >= 0, coord.y < grid.count, coord.x >= 0, coord.x < grid[coord.y].count else { return nil }
            switch grid[coord.y][coord.x] {
            case "g": return .grass
            case "b": return .beach
            case "w": return .water
            case "f": return .forest
            default: return .mountain
            }
        }
    }

    @Test("scenario: Grass meeting beach picks a transition tile")
    func grassMeetingBeach() {
        // The grass tile at (1, 1); its +row neighbours are beach.
        let terrain = map([
            "ggg",
            "ggg",
            "bbb"
        ])
        let transition = TerrainCorners.transition(at: TileCoordinate(x: 1, y: 1), terrain: terrain)
        #expect(transition == TerrainTransition(upper: .grass, lower: .beach, mask: 0b0011))
        #expect(transition?.assetName == "terrain-grass-beach-t3")
    }

    @Test("scenario: Grass beside water shows a beach edge")
    func grassBesideWater() {
        let terrain = map([
            "ggg",
            "ggg",
            "www",
            "www"
        ])
        // The two shared vertices are beach.
        #expect(TerrainCorners.vertex(TileCoordinate(x: 1, y: 2), terrain: terrain) == .beach)
        #expect(TerrainCorners.vertex(TileCoordinate(x: 2, y: 2), terrain: terrain) == .beach)
        // Grass keeps its two far corners as grass…
        #expect(TerrainCorners.transition(at: TileCoordinate(x: 1, y: 1), terrain: terrain)
            == TerrainTransition(upper: .grass, lower: .beach, mask: 0b0011))
        // …and the water tile keeps its two far corners as water.
        #expect(TerrainCorners.transition(at: TileCoordinate(x: 1, y: 2), terrain: terrain)
            == TerrainTransition(upper: .beach, lower: .water, mask: 0b0011))
    }

    @Test("scenario: Transitions do not change gameplay")
    func transitionsAreVisualOnly() throws {
        let base = World.fixtureWithTerrain(width: 3, height: 3, fill: .grass, seed: 1).snapshot()
        let grid = (0 ..< 9).map { $0 / 3 == 2 ? TerrainType.beach : .grass }
        let snapshot = WorldSnapshot(
            tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: 3, mapHeight: 3,
            terrainGrid: grid, occupiedTiles: [:], buildings: [:], carriers: [], economy: base.economy,
            totalPopulation: 0, camera: base.camera
        )
        let specs = SnapshotReconciler.desiredSprites(in: snapshot, xRange: 0 ... 2, yRange: 0 ... 2)
        let middle = try #require(specs.first { $0.coord == TileCoordinate(x: 1, y: 1) })
        #expect(middle.kind == .terrain(.grass, transition: TerrainTransition(upper: .grass, lower: .beach, mask: 0b0011)))
        #expect(snapshot.terrain(at: TileCoordinate(x: 1, y: 1)) == .grass)
    }

    @Test("uniform tiles, forest and mountain keep their own sprite")
    func noTransitionWhereNothingChanges() {
        let terrain = map([
            "fff",
            "fmf",
            "www"
        ])
        #expect(TerrainCorners.transition(at: TileCoordinate(x: 1, y: 0), terrain: terrain) == nil) // forest
        #expect(TerrainCorners.transition(at: TileCoordinate(x: 1, y: 1), terrain: terrain) == nil) // mountain
        #expect(TerrainCorners.transition(at: TileCoordinate(x: 1, y: 0), terrain: map(["ggg", "ggg"])) == nil)
    }

    @Test("forest beside water gives the water tile a beach edge")
    func forestCountsAsGrassForVertices() {
        let terrain = map([
            "fff",
            "www",
            "www"
        ])
        #expect(TerrainCorners.transition(at: TileCoordinate(x: 1, y: 1), terrain: terrain)
            == TerrainTransition(upper: .beach, lower: .water, mask: 0b0011))
    }

    @Test("off-map neighbours are ignored")
    func mapEdge() {
        let terrain = map(["bw"])
        #expect(TerrainCorners.vertex(TileCoordinate(x: 0, y: 0), terrain: terrain) == .beach)
        #expect(TerrainCorners.vertex(TileCoordinate(x: 1, y: 0), terrain: terrain) == .water)
    }
}
