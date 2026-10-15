import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/terrain-v2 (rendering-2_5d / Ground macro field).

private func grid(_ width: Int, _ height: Int, fill: TerrainType, _ paint: (Int, Int) -> TerrainType? = { _, _ in nil }) -> [TerrainType] {
    (0 ..< width * height).map { paint($0 % width, $0 / width) ?? fill }
}

private func brightness(_ colour: SIMD3<Float>) -> Float {
    colour.x + colour.y + colour.z
}

@Test("scenario: Neighbouring grass tiles differ smoothly")
func neighbouringGrassTilesDifferSmoothly() {
    let field = GroundMacroField(width: 40, height: 40, grid: grid(40, 40, fill: .grass), occupied: [], season: .summer)
    var steepest: Float = 0, lowest: Float = 9, highest: Float = 0
    for y in 2 ..< 38 {
        for x in 2 ..< 38 {
            let here = brightness(field.multiplier(atVertex: .init(x: x, y: y)))
            let right = brightness(field.multiplier(atVertex: .init(x: x + 1, y: y)))
            let below = brightness(field.multiplier(atVertex: .init(x: x, y: y + 1)))
            steepest = max(steepest, abs(here - right), abs(here - below))
            lowest = min(lowest, here)
            highest = max(highest, here)
        }
    }
    #expect(steepest < 0.5, "steepest step \(steepest)")
    #expect(highest - lowest > 0.6, "range \(highest - lowest)")
}

@Test("scenario: Deep water is darker than shallow water")
func deepWaterIsDarkerThanShallowWater() {
    let sea = grid(30, 30, fill: .water) { x, y in (12 ..< 18).contains(x) && (12 ..< 18).contains(y) ? .grass : nil }
    let field = GroundMacroField(width: 30, height: 30, grid: sea, occupied: [], season: .summer)
    let shallow = field.multiplier(atVertex: TileCoordinate(x: 11, y: 15))
    let deep = field.multiplier(atVertex: TileCoordinate(x: 5, y: 15))
    #expect(brightness(deep) < brightness(shallow) * 0.75)
}

@Test("scenario: Forest floor is darker than meadow")
func forestFloorIsDarkerThanMeadow() {
    let wood = grid(30, 30, fill: .grass) { x, y in (10 ..< 17).contains(x) && (10 ..< 17).contains(y) ? .forest : nil }
    let field = GroundMacroField(width: 30, height: 30, grid: wood, occupied: [], season: .summer)
    let floor = field.multiplier(atVertex: TileCoordinate(x: 13, y: 13))
    let meadow = field.multiplier(atVertex: TileCoordinate(x: 13, y: 21))
    #expect(brightness(floor) < brightness(meadow) * 0.85)
}

@Test("scenario: Building a house wears the ground")
func buildingAHouseWearsTheGround() {
    let meadow = grid(30, 30, fill: .grass)
    let footprint: Set<TileCoordinate> = [.init(x: 10, y: 10), .init(x: 11, y: 10), .init(x: 10, y: 11), .init(x: 11, y: 11)]
    let before = GroundMacroField(width: 30, height: 30, grid: meadow, occupied: [], season: .summer)
    let after = GroundMacroField(width: 30, height: 30, grid: meadow, occupied: footprint, season: .summer)
    let next = TileCoordinate(x: 13, y: 11)
    let browner = after.multiplier(atVertex: next) / before.multiplier(atVertex: next)
    #expect(browner.x > browner.z)
    let away = TileCoordinate(x: 15, y: 11)
    #expect(after.multiplier(atVertex: away) == before.multiplier(atVertex: away))
}

@Test("The macro field is neutral off the map")
func macroFieldIsNeutralOffTheMap() {
    let field = GroundMacroField(width: 8, height: 8, grid: grid(8, 8, fill: .water), occupied: [], season: .summer)
    #expect(Array(field.pixels[0 ..< 4]) == [128, 128, 128, 255])
    #expect(field.width == 32 && field.height == 16)
}

private func snapshot(season: Season, occupied: [TileCoordinate: EntityID] = [:]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1).snapshot()
    return WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth,
        mapHeight: base.mapHeight, terrainGrid: base.terrainGrid, occupiedTiles: occupied,
        buildings: base.buildings, carriers: base.carriers, economy: base.economy,
        totalPopulation: base.totalPopulation, camera: base.camera,
        date: GameDate(year: 1200, season: season)
    )
}

@Test("scenario: The macro field is rebuilt only on change")
func macroFieldIsRebuiltOnlyOnChange() {
    var cache = GroundMacroCache()
    #expect(cache.inputs(for: snapshot(season: .spring)) != nil)
    #expect(cache.inputs(for: snapshot(season: .spring)) == nil)
    #expect(cache.inputs(for: snapshot(season: .summer)) == nil)
    #expect(cache.inputs(for: snapshot(season: .spring, occupied: [.init(x: 2, y: 2): EntityID(raw: 1)])) != nil)
    #expect(cache.computations == 2)
}

@Test("scenario: The macro field follows the season")
func macroFieldFollowsTheSeason() throws {
    var cache = GroundMacroCache()
    let first = cache.inputs(for: snapshot(season: .spring))
    let second = cache.inputs(for: snapshot(season: .winter))
    let spring = try #require(first).build()
    let winter = try #require(second).build()
    #expect(spring.pixels != winter.pixels)
}

@MainActor
private final class FixedSource: IsoWorldDataSource {
    var snapshot: WorldSnapshot
    init(_ snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

/// Updates the scene until its macro field shows `occupied`, for at most two seconds.
@MainActor
private func settle(_ scene: IsoWorldScene, showing occupied: Set<TileCoordinate>) async {
    for _ in 0 ..< 200 where scene.groundMacroShown?.occupied != occupied {
        scene.update(0)
        try? await Task.sleep(for: .milliseconds(10))
    }
}

@MainActor
@Test("The scene multiplies the macro field over the ground, under objects and buildings")
func sceneDrawsTheMacroFieldBetweenGroundAndBuildings() async throws {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    let source = FixedSource(snapshot(season: .spring))
    scene.dataSource = source
    await settle(scene, showing: [])
    let node = try #require(scene.childNode(withName: IsoWorldScene.groundMacroNodeName) as? SKSpriteNode)
    #expect(node.blendMode == .multiplyX2)
    #expect(node.zPosition > 0 && node.zPosition < 10)
    #expect(node.size == CGSize(width: 16 * 32, height: 16 * 16))
}

@MainActor
@Test("Rapid changes end on the newest field")
func rapidChangesEndOnTheNewestField() async {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    let source = FixedSource(snapshot(season: .spring))
    scene.dataSource = source
    for x in 1 ... 3 {
        source.snapshot = snapshot(season: .spring, occupied: [.init(x: x, y: 2): EntityID(raw: UInt32(x))])
        scene.update(0)
    }
    await settle(scene, showing: [.init(x: 3, y: 2)])
    #expect(scene.groundMacroShown?.occupied == [.init(x: 3, y: 2)])
}

@Test("Texels just outside the map's edge carry the edge's colour, not neutral grey")
func borderTexelsCarryTheEdgeColour() {
    let field = GroundMacroField(width: 12, height: 12, grid: grid(12, 12, fill: .water), occupied: [], season: .summer)
    var checked = 0
    for row in 0 ..< field.height {
        for column in 0 ..< field.width {
            let point = CGPoint(x: field.topLeft.x + (CGFloat(column) + 0.5) * 16, y: field.topLeft.y - (CGFloat(row) + 0.5) * 16)
            let tile = IsoMath.tileCoordinate(forScreenPoint: point)
            let vx = tile.col + 0.5, vy = tile.row + 0.5
            // Within half a texel outside the north-west edge, alongside the map.
            guard vx < 0, vx > -0.25, vy > 1, vy < 11 else { continue }
            let base = (row * field.width + column) * 4
            #expect(Array(field.pixels[base ..< base + 3]) != [128, 128, 128])
            checked += 1
        }
    }
    #expect(checked > 0)
}

@Test("Beaches keep their colour beside the sea")
func beachesKeepTheirColourBesideTheSea() {
    let coast = grid(20, 20, fill: .water) { x, _ in x < 8 ? .grass : x < 10 ? .beach : nil }
    let field = GroundMacroField(width: 20, height: 20, grid: coast, occupied: [], season: .summer)
    let shore = field.multiplier(atVertex: TileCoordinate(x: 10, y: 10))
    #expect(shore.y <= shore.x * 1.03, "beach edge tinted \(shore)")
}
