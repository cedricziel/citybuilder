import Foundation
import Testing
@testable import CityCore

// Owner seams of the age signatures: signature effects, the
// one-monument rule and the monument tax bonus stay within one owner.

private typealias Fixture = SignatureFixture

@Test("signature owners match only on the same owner")
func signatureOwnersMatchOnlyOnTheSameOwner() {
    let player = Building(id: EntityID(raw: 1), kind: .guildHall, anchor: TileCoordinate(x: 0, y: 0))
    let rival = Building(id: EntityID(raw: 2), kind: .sawmill, anchor: TileCoordinate(x: 4, y: 0), owner: .rival(1))
    let otherRival = Building(id: EntityID(raw: 3), kind: .sawmill, anchor: TileCoordinate(x: 8, y: 0), owner: .rival(2))
    #expect(World.haveSameOwner(player, player))
    #expect(!World.haveSameOwner(player, rival))
    #expect(!World.haveSameOwner(rival, otherRival))
    #expect(World.haveSameOwner(rival, rival))
}

@Test("a rival guild hall doesn't speed up the player's sawmill")
func rivalGuildHallDoesNotSpeedUpThePlayersSawmill() {
    var world = Fixture.grass()
    Fixture.inject(.guildHall, at: TileCoordinate(x: 2, y: 2), in: &world, owner: .rival(1))
    let sawmill = Fixture.suppliedSawmill(at: TileCoordinate(x: 8, y: 2), in: &world)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 25)
}

@Test("a rival's monument doesn't block the player's")
func rivalMonumentDoesNotBlockThePlayers() {
    var world = Fixture.grass()
    world.testAddBuilding(.monument, owner: .rival(1))
    #expect(world.canPlace(.monument, at: TileCoordinate(x: 10, y: 2)) == .allowed)
    #expect(world.uniquenessRejection(.monument, for: .rival(1)) == .alreadyBuilt(.monument))
}

@Test("a rival's finished monument raises only the rival's tax")
func rivalMonumentRaisesOnlyTheRivalsTax() throws {
    var world = Fixture.grass()
    world.testSeatRival()
    let monument = world.testAddBuilding(.monument, owner: .rival(1))
    world.buildings[monument]?.projectStages = 25
    Fixture.runUntilBefore(multipleOf: Economy.taxIntervalTicks, in: &world)
    world.testAddHouse(owner: .player, residents: 8, tier: .merchants)
    world.testAddHouse(owner: .rival(1), residents: 8, tier: .merchants)
    let balance = world.economy.balance
    let treasury = try #require(world.rival(1)).treasury
    world.tick()
    // 8 merchants pay $32; the monument adds 10 % for its owner only.
    #expect(world.economy.balance == balance + 32)
    #expect(world.rival(1)?.treasury == treasury + 35)
}
