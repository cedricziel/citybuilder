import CityCore
import CoreGraphics
import SpriteKit
import Testing
@testable import CityRender2D

// The building pass skips frames where only what a house sprite doesn't show changed: its population
// counts move every tick, but only the tier and smoke are drawn.

private let house = Building(id: EntityID(raw: 1), kind: .house, anchor: TileCoordinate(x: 4, y: 4), state: .operational)

/// A 10 × 10 meadow with one house, `population` in it, under `modifiers`.
private func meadow(population: HousePopulation, modifiers: HouseModifiers = .none) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1).snapshot()
    let footprint = BuildingCatalog.spec(for: .house).footprint.tiles(anchor: house.anchor)
    return WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: 10, mapHeight: 10,
        terrainGrid: base.terrainGrid, occupiedTiles: Dictionary(uniqueKeysWithValues: footprint.map { ($0, house.id) }),
        buildings: [house.id: house], carriers: [], economy: base.economy, totalPopulation: base.totalPopulation,
        camera: Camera(centerX: 5, centerY: 5, zoom: 1), housePopulations: [house.id: population],
        houseModifiers: modifiers == .none ? [:] : [house.id: modifiers]
    )
}

private func population(_ count: UInt32, tier: HouseTier = .peasants) -> HousePopulation {
    var population = HousePopulation()
    population.population = count
    population.tier = tier
    population.ticksAtCurrentSatisfaction = UInt64(count) * 7
    return population
}

/// Draws `first`, then `second`, and reports whether the house kept its node and how many building
/// passes the second frame ran.
@MainActor
private func redraw(from first: WorldSnapshot, to second: WorldSnapshot) throws -> (keptNode: Bool, passes: Int) {
    let source = FixedSnapshotSource(first)
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 480, height: 320)
    scene.hasSprite = { _ in true }
    scene.dataSource = source
    scene.update(0)
    let node = try #require(scene.buildingNodes[house.anchor])
    let passes = scene.spriteReconcileCounts.buildingPasses
    source.snapshot = second
    scene.update(1)
    return (scene.buildingNodes[house.anchor] === node, scene.spriteReconcileCounts.buildingPasses - passes)
}

@MainActor
@Test("a house's population counts changing keeps its node")
func populationCountsChangingKeepsTheNode() throws {
    let result = try redraw(from: meadow(population: population(3)), to: meadow(population: population(4)))
    #expect(result.keptNode)
    #expect(result.passes == 0)
}

@MainActor
@Test("a house modifier the sprite doesn't show keeps its node")
func unseenModifierKeepsTheNode() throws {
    let result = try redraw(
        from: meadow(population: population(3)),
        to: meadow(population: population(3), modifiers: HouseModifiers(energised: true, inspired: true))
    )
    #expect(result.keptNode)
    #expect(result.passes == 0)
}

@MainActor
@Test("a new tier or smoke redraws the house", arguments: [
    (population(3, tier: .citizens), HouseModifiers.none),
    (population(3), HouseModifiers(smoky: true))
])
func newTierOrSmokeRedrawsTheHouse(after: HousePopulation, modifiers: HouseModifiers) throws {
    let result = try redraw(from: meadow(population: population(3)), to: meadow(population: after, modifiers: modifiers))
    #expect(!result.keptNode)
    #expect(result.passes == 1)
}
