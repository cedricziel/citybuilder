import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-age-signatures: catalog, unlocks,
// ranges and saves (milestone M1).

private typealias Fixture = SignatureFixture

/// A new game in `age` with materials to spare, so placement checks only
/// fail for research, occupancy and the one-monument rule.
private func game(_ age: Age) -> World {
    var world = World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, age: age)
    world.seedUnlimitedTestInventory()
    world.testMaterialCredits[.iron] = 999
    return world
}

/// First anchor whose footprint lies on free grass.
private func freeAnchor(for kind: BuildingKind, in world: World) -> TileCoordinate? {
    let footprint = BuildingCatalog.spec(for: kind).footprint
    for y in 0 ..< world.mapHeight {
        for x in 0 ..< world.mapWidth {
            let anchor = TileCoordinate(x: x, y: y)
            let fits = footprint.tiles(anchor: anchor).allSatisfy {
                world.terrain(at: $0) == .grass && world.occupiedTiles[$0] == nil
            }
            if fits { return anchor }
        }
    }
    return nil
}

private func placement(_ kind: BuildingKind, in world: World) throws -> PlacementResult {
    try world.canPlace(kind, at: #require(freeAnchor(for: kind, in: world)))
}

@Test("scenario: era tech unlock lists")
func scenarioEraTechUnlockLists() {
    #expect(Tech.feudalOrder.unlocks == [.guildHall])
    #expect(Tech.printingPress.unlocks == [.gallery])
    #expect(Tech.steamPower.unlocks == [.steamEngine])
    #expect(Tech.electricity.unlocks == [.powerPlant])
    #expect(Tech.unlocking(.monument) == nil)
}

@Test("scenario: gallery locked before printing press")
func scenarioGalleryLockedBeforePrintingPress() throws {
    #expect(try placement(.gallery, in: game(.medieval)) == .rejected(.locked(.printingPress)))
}

@Test("scenario: renaissance start has three signatures")
func scenarioRenaissanceStartHasThreeSignatures() throws {
    let world = game(.renaissance)
    #expect(try placement(.monument, in: world) == .allowed)
    #expect(try placement(.guildHall, in: world) == .allowed)
    #expect(try placement(.gallery, in: world) == .allowed)
    #expect(try placement(.steamEngine, in: world) == .rejected(.locked(.steamPower)))
}

@Test("scenario: antiquity start has the monument")
func scenarioAntiquityStartHasTheMonument() throws {
    let world = game(.antiquity)
    #expect(try placement(.monument, in: world) == .allowed)
    #expect(try placement(.guildHall, in: world) == .rejected(.locked(.feudalOrder)))
}

@Test("scenario: steam engine spec")
func scenarioSteamEngineSpec() {
    let spec = BuildingCatalog.spec(for: .steamEngine)
    #expect(spec.footprint == Footprint(width: 2, height: 2))
    #expect(spec.cost == 220)
    #expect(spec.materialCost == [.wood: 2, .planks: 4, .iron: 2])
    #expect(spec.upkeep == 3)
}

@Test("signature catalog entries match the design table")
func signatureCatalogEntries() {
    let monument = BuildingCatalog.spec(for: .monument)
    #expect(monument.footprint == Footprint(width: 3, height: 3))
    #expect(monument.cost == 300 && monument.upkeep == 0 && monument.buildDurationTicks == 60)
    #expect(monument.materialCost == [.wood: 6, .planks: 6])
    let guild = BuildingCatalog.spec(for: .guildHall)
    #expect(guild.cost == 250 && guild.upkeep == 3 && guild.materialCost == [.wood: 4, .planks: 6])
    let gallery = BuildingCatalog.spec(for: .gallery)
    #expect(gallery.footprint == Footprint(width: 2, height: 2))
    #expect(gallery.cost == 180 && gallery.upkeep == 2 && gallery.materialCost == [.wood: 2, .planks: 4])
    let plant = BuildingCatalog.spec(for: .powerPlant)
    #expect(plant.cost == 400 && plant.upkeep == 6 && plant.materialCost == [.planks: 6, .iron: 4])
    #expect(World.stockpileCapacity(for: .monument) == 16)
    #expect(World.stockpileCapacity(for: .steamEngine) == 16)
    #expect(World.stockpileCapacity(for: .powerPlant) == 16)
    #expect(World.stockpileCapacity(for: .guildHall) == nil)
    #expect(World.stockpileCapacity(for: .gallery) == nil)
}

@Test("scenario: touching footprints")
func scenarioTouchingFootprints() throws {
    var world = Fixture.grass()
    let guild = Fixture.inject(.guildHall, at: TileCoordinate(x: 2, y: 2), in: &world)
    let sawmill = Fixture.inject(.sawmill, at: TileCoordinate(x: 5, y: 3), in: &world)
    let distance = try World.footprintDistance(#require(world.buildings[guild]), #require(world.buildings[sawmill]))
    #expect(distance == 1)
}

@Test("footprint distance is the chebyshev gap in either direction")
func footprintDistanceIsSymmetric() throws {
    var world = Fixture.grass()
    let guild = Fixture.inject(.guildHall, at: TileCoordinate(x: 10, y: 10), in: &world)
    let left = Fixture.inject(.sawmill, at: TileCoordinate(x: 2, y: 11), in: &world)
    let below = Fixture.inject(.sawmill, at: TileCoordinate(x: 14, y: 20), in: &world)
    let overlapping = Building(id: EntityID(raw: 999), kind: .house, anchor: TileCoordinate(x: 11, y: 11))
    #expect(try World.footprintDistance(#require(world.buildings[guild]), #require(world.buildings[left])) == 7)
    #expect(try World.footprintDistance(#require(world.buildings[left]), #require(world.buildings[guild])) == 7)
    #expect(try World.footprintDistance(#require(world.buildings[guild]), #require(world.buildings[below])) == 8)
    #expect(try World.footprintDistance(#require(world.buildings[guild]), overlapping) == 0)
}

@Test("scenario: just out of range")
func scenarioJustOutOfRange() throws {
    var world = Fixture.grass()
    Fixture.inject(.guildHall, at: TileCoordinate(x: 2, y: 2), in: &world)
    // The guild hall spans x 2…4, so a sawmill at x 13 is 9 tiles away.
    let sawmill = Fixture.suppliedSawmill(at: TileCoordinate(x: 13, y: 2), in: &world)
    #expect(try World.footprintDistance(
        #require(world.buildings[sawmill]),
        #require(world.buildings.values.first { $0.kind == .guildHall })
    ) == 9)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 25)
}

@Test("scenario: smelters are workshops")
func scenarioSmeltersAreWorkshops() {
    let workshops: [BuildingKind] = [.sawmill, .bakery, .windmill, .quernHouse, .charcoalBurner, .smelter, .toolsmith]
    let others: [BuildingKind] = [.farm, .grainFarm, .lumberjackHut, .mine, .shipyard, .monument]
    let cultureProducers: [BuildingKind] = [.brewery, .winery, .teaHouse, .roastery]
    #expect((workshops + cultureProducers).filter(\.isWorkshop) == workshops + cultureProducers)
    #expect(others.filter(\.isWorkshop).isEmpty)
}

@Test("scenario: second monument")
func scenarioSecondMonument() {
    var world = Fixture.grass()
    Fixture.inject(.monument, at: TileCoordinate(x: 2, y: 2), in: &world, state: .constructing)
    #expect(world.canPlace(.monument, at: TileCoordinate(x: 10, y: 2)) == .rejected(.alreadyBuilt(.monument)))
}

@Test("scenario: rebuilding after demolition")
func scenarioRebuildingAfterDemolition() throws {
    var world = Fixture.grass()
    let old = Fixture.inject(.monument, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.buildings[old]?.projectStages = 10
    world.enqueue(.demolish(at: TileCoordinate(x: 2, y: 2)))
    world.tick()
    #expect(world.canPlace(.monument, at: TileCoordinate(x: 10, y: 2)) == .allowed)
    world.enqueue(.place(.monument, at: TileCoordinate(x: 10, y: 2)))
    world.tick()
    let new = try #require(world.occupiedTiles[TileCoordinate(x: 10, y: 2)])
    #expect(world.buildings[new]?.projectStages == 0)
}

@Test("scenario: older building loads")
func scenarioOlderBuildingLoads() throws {
    var building = Building(id: EntityID(raw: 7), kind: .sawmill, anchor: TileCoordinate(x: 1, y: 1), state: .operational)
    building.projectStages = 3
    building.fuelled = true
    building.commissionTicksLeft = 40
    let encoded = try JSONEncoder().encode(building)
    var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(json["projectStages"] != nil)
    for key in ["projectStages", "fuelled", "commissionTicksLeft"] {
        json.removeValue(forKey: key)
    }
    let old = try JSONDecoder().decode(Building.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(old.projectStages == 0)
    #expect(!old.fuelled)
    #expect(old.commissionTicksLeft == 0)
    let roundTrip = try JSONDecoder().decode(Building.self, from: encoded)
    #expect(roundTrip == building)
}
