import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-age-signatures: house capacity,
// the monument, taxes and gallery commissions (milestone M3).

private typealias Fixture = SignatureFixture

/// A warehouse full of goods on a road along y = 4, and a house at
/// (6, 2) on the same road.
private struct Street {
    var world: World
    let warehouse: EntityID
    let house: EntityID

    init(tier: HouseTier, residents: UInt32, goods: [Good]? = nil) {
        world = Fixture.grass()
        let goods = goods ?? HouseTier.merchants.needs(in: world.culture)
        warehouse = Fixture.inject(.warehouse, at: TileCoordinate(x: 0, y: 1), in: &world)
        for good in goods {
            world.stockpiles[warehouse]?.deposit(good, amount: 40)
        }
        for x in 0 ... 30 {
            world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 4)))
        }
        house = Fixture.inject(.house, at: TileCoordinate(x: 6, y: 2), in: &world)
        var pop = HousePopulation()
        pop.tier = tier
        pop.population = residents
        world.populations[house] = pop
    }

    /// Anchor `gap` tiles east of the house, on the same row.
    func east(_ gap: Int) -> TileCoordinate {
        TileCoordinate(x: 7 + gap, y: 2)
    }

    var population: UInt32? {
        world.populations[house]?.population
    }
}

// MARK: - Capacity

@Test("scenario: smoky merchants")
func scenarioSmokyMerchants() {
    var street = Street(tier: .merchants, residents: 8)
    Fixture.fuelled(.steamEngine, at: street.east(3), in: &street.world)
    #expect(street.world.houseCapacity(of: street.house) == 6)
}

@Test("scenario: cold engine")
func scenarioColdEngine() {
    var street = Street(tier: .merchants, residents: 8)
    Fixture.inject(.steamEngine, at: street.east(3), in: &street.world)
    #expect(street.world.houseCapacity(of: street.house) == 8)
}

@Test("scenario: energised merchants")
func scenarioEnergisedMerchants() {
    var street = Street(tier: .merchants, residents: 8)
    Fixture.fuelled(.powerPlant, at: street.east(9), in: &street.world)
    #expect(street.world.houseCapacity(of: street.house) == 10)
}

@Test("scenario: smoky and energised")
func scenarioSmokyAndEnergised() {
    var street = Street(tier: .merchants, residents: 8)
    Fixture.fuelled(.steamEngine, at: street.east(4), in: &street.world)
    Fixture.fuelled(.powerPlant, at: TileCoordinate(x: 12, y: 10), in: &street.world)
    #expect(street.world.houseCapacity(of: street.house) == 8)
    #expect(street.world.houseModifiers(of: street.house) == HouseModifiers(smoky: true, energised: true, inspired: false))
}

@Test("scenario: smoky peasants")
func scenarioSmokyPeasants() {
    var street = Street(tier: .peasants, residents: 1)
    Fixture.fuelled(.steamEngine, at: street.east(2), in: &street.world)
    #expect(street.world.houseCapacity(of: street.house) == 2)
}

@Test("scenario: smoke drives residents out")
func scenarioSmokeDrivesResidentsOut() {
    var street = Street(tier: .merchants, residents: 8)
    Fixture.fuelled(.steamEngine, at: street.east(3), in: &street.world)
    _ = Fixture.run(&street.world, ticks: 59)
    #expect(street.population == 8)
    _ = Fixture.run(&street.world, ticks: 1)
    #expect(street.population == 7)
    _ = Fixture.run(&street.world, ticks: 60)
    #expect(street.population == 6)
    _ = Fixture.run(&street.world, ticks: 120)
    #expect(street.population == 6)
    #expect(street.world.populations[street.house]?.tier == .merchants)
}

@Test("scenario: energised house is not full at 4")
func scenarioEnergisedHouseIsNotFullAt4() {
    var street = Street(tier: .peasants, residents: 4, goods: [.food, .planks])
    Fixture.fuelled(.powerPlant, at: street.east(5), in: &street.world)
    street.world.populations[street.house]?.ticksAtCurrentSatisfaction = 0
    _ = Fixture.run(&street.world, ticks: 120)
    #expect(street.world.populations[street.house]?.tier == .peasants)
    #expect(street.world.houseCapacity(of: street.house) == 6)
}

// MARK: - Monument

@Test("scenario: one stage")
func scenarioOneStage() {
    var world = Fixture.grass()
    let monument = Fixture.inject(.monument, at: TileCoordinate(x: 2, y: 2), in: &world)
    for (good, amount) in [(Good.wood, 2), (.planks, 2), (.bread, 1)] {
        world.stockpiles[monument]?.deposit(good, amount: amount)
    }
    _ = Fixture.run(&world, ticks: 59)
    #expect(world.buildings[monument]?.projectStages == 0)
    _ = Fixture.run(&world, ticks: 1)
    #expect(world.buildings[monument]?.projectStages == 1)
    #expect(world.stockpiles[monument]?.totalStored == 0)
}

@Test("scenario: completion")
func scenarioCompletion() {
    var world = Fixture.grass()
    let monument = Fixture.inject(.monument, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.buildings[monument]?.projectStages = 24
    for (good, amount) in [(Good.wood, 2), (.planks, 2), (.bread, 1)] {
        world.stockpiles[monument]?.deposit(good, amount: amount)
    }
    let events = Fixture.run(&world, ticks: 60)
    #expect(world.buildings[monument]?.projectStages == 25)
    #expect(events.contains(.monumentCompleted(building: monument)))
}

@Test("scenario: finished monument consumes nothing")
func scenarioFinishedMonumentConsumesNothing() {
    var street = Street(tier: .peasants, residents: 0, goods: [.wood, .planks, .bread])
    let monument = Fixture.inject(.monument, at: street.east(4), in: &street.world)
    street.world.buildings[monument]?.projectStages = 25
    for (good, amount) in [(Good.wood, 2), (.planks, 2), (.bread, 1)] {
        street.world.stockpiles[monument]?.deposit(good, amount: amount)
    }
    let events = Fixture.run(&street.world, ticks: 120)
    #expect(street.world.buildings[monument]?.projectStages == 25)
    #expect(street.world.stockpiles[monument]?.totalStored == 5)
    let headedThere = street.world.carriers.values.contains {
        if case let .retrieve(_, _, _, consumer) = $0.mission { return consumer == monument }
        return false
    }
    #expect(!headedThere)
    #expect(!events.contains(.monumentCompleted(building: monument)))
}

@Test("an unfinished monument is supplied with its project goods")
func unfinishedMonumentIsSupplied() {
    var street = Street(tier: .peasants, residents: 0, goods: [.wood, .planks, .bread])
    let monument = Fixture.inject(.monument, at: street.east(4), in: &street.world)
    var delivered: Set<Good> = []
    for _ in 0 ..< 200 {
        street.world.tick()
        for carrier in street.world.carriers.values {
            if case let .retrieve(good, _, _, consumer) = carrier.mission, consumer == monument {
                delivered.insert(good)
            }
        }
    }
    #expect(delivered == [.wood, .planks, .bread])
}

@Test("scenario: monument bonus")
func scenarioMonumentBonus() {
    var world = Fixture.grass()
    let monument = Fixture.inject(.monument, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.buildings[monument]?.projectStages = 25
    let house = Fixture.inject(.house, at: TileCoordinate(x: 10, y: 2), in: &world)
    Fixture.runUntilBefore(multipleOf: Economy.taxIntervalTicks, in: &world)
    var pop = HousePopulation()
    pop.tier = .merchants
    pop.population = 8
    world.populations[house] = pop
    let before = world.economy.balance
    world.tick()
    #expect(world.economy.balance == before + 35)
}

@Test("an unfinished monument adds no tax")
func unfinishedMonumentAddsNoTax() {
    var world = Fixture.grass()
    let monument = Fixture.inject(.monument, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.buildings[monument]?.projectStages = 24
    let house = Fixture.inject(.house, at: TileCoordinate(x: 10, y: 2), in: &world)
    Fixture.runUntilBefore(multipleOf: Economy.taxIntervalTicks, in: &world)
    var pop = HousePopulation()
    pop.tier = .merchants
    pop.population = 8
    world.populations[house] = pop
    let before = world.economy.balance
    world.tick()
    #expect(world.economy.balance == before + 32)
}

// MARK: - Gallery

@Test("scenario: commissioning")
func scenarioCommissioning() {
    var world = Fixture.grass()
    let gallery = Fixture.inject(.gallery, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.economy.balance = 500
    world.enqueue(.commission(gallery))
    let events = world.tick().events
    #expect(world.economy.balance == 300)
    #expect(world.buildings[gallery]?.commissionTicksLeft == 1200)
    #expect(events.contains(.commissionStarted(building: gallery)))
    world.enqueue(.commission(gallery))
    world.tick()
    #expect(world.economy.balance == 300)
    #expect(world.buildings[gallery]?.commissionTicksLeft == 1199)
}

@Test("scenario: too poor to commission")
func scenarioTooPoorToCommission() {
    var world = Fixture.grass()
    let gallery = Fixture.inject(.gallery, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.economy.balance = 150
    world.enqueue(.commission(gallery))
    world.tick()
    #expect(world.economy.balance == 150)
    #expect(world.buildings[gallery]?.commissionTicksLeft == 0)
}

@Test("commissions only apply to operational galleries")
func commissionNeedsAnOperationalGallery() {
    var world = Fixture.grass()
    let sawmill = Fixture.inject(.sawmill, at: TileCoordinate(x: 2, y: 2), in: &world)
    let site = Fixture.inject(.gallery, at: TileCoordinate(x: 8, y: 2), in: &world, state: .constructing)
    world.buildings[site]?.constructionState = .waitingForMaterials
    world.economy.balance = 500
    world.enqueue(.commission(sawmill))
    world.enqueue(.commission(site))
    world.tick()
    #expect(world.economy.balance == 500)
}

@Test("scenario: inspired house grows faster")
func scenarioInspiredHouseGrowsFaster() {
    var street = Street(tier: .peasants, residents: 1, goods: [.food])
    let gallery = Fixture.inject(.gallery, at: street.east(4), in: &street.world)
    street.world.buildings[gallery]?.commissionTicksLeft = 1200
    _ = Fixture.run(&street.world, ticks: 29)
    #expect(street.population == 1)
    _ = Fixture.run(&street.world, ticks: 1)
    #expect(street.population == 2)
    #expect(street.world.houseModifiers(of: street.house).inspired)
}

@Test("scenario: commission ends")
func scenarioCommissionEnds() {
    var street = Street(tier: .peasants, residents: 1, goods: [.food])
    let gallery = Fixture.inject(.gallery, at: street.east(4), in: &street.world)
    street.world.economy.balance = 500
    street.world.enqueue(.commission(gallery))
    street.world.tick()
    let events = Fixture.run(&street.world, ticks: 1200)
    #expect(events.count { $0 == .commissionEnded(building: gallery) } == 1)
    #expect(street.world.tick().events.allSatisfy { $0 != .commissionEnded(building: gallery) })
    street.world.populations[street.house]?.population = 1
    street.world.populations[street.house]?.ticksAtCurrentSatisfaction = 0
    _ = Fixture.run(&street.world, ticks: 30)
    #expect(street.population == 1)
    _ = Fixture.run(&street.world, ticks: 30)
    #expect(street.population == 2)
}
