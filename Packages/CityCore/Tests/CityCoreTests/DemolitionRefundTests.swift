import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/demolish-refund-confirm (economy /
// Demolishing refunds half the build cost).

private func demolish(_ id: EntityID, in world: inout World) {
    guard let anchor = world.buildings[id]?.anchor else { return }
    var events: [WorldEvent] = []
    world.applyDemolish(anchor: anchor, events: &events)
}

private func building(_ kind: BuildingKind, state: BuildingState = .operational) -> Building {
    Building(id: EntityID(raw: 1), kind: kind, anchor: TileCoordinate(x: 0, y: 0), state: state)
}

@Test("scenario: demolishing a building refunds half its cost")
func scenarioDemolishingABuildingRefundsHalfItsCost() {
    var world = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1)
    let sawmill = SignatureFixture.inject(.sawmill, at: TileCoordinate(x: 0, y: 0), in: &world)
    let site = SignatureFixture.inject(.house, at: TileCoordinate(x: 6, y: 6), in: &world, state: .constructing)
    world.economy.balance = 1000
    demolish(sawmill, in: &world)
    #expect(world.economy.balance == 1060)
    #expect(world.buildings[sawmill] == nil)
    demolish(site, in: &world)
    #expect(world.economy.balance == 1085)
}

@Test("scenario: ruins and burning buildings refund nothing")
func scenarioRuinsAndBurningBuildingsRefundNothing() {
    #expect(World.demolitionRefund(for: building(.house)) == 25)
    #expect(World.demolitionRefund(for: building(.road)) == 2)
    #expect(World.demolitionRefund(for: building(.house, state: .burning)) == 0)
    #expect(World.demolitionRefund(for: building(.ruins)) == 0)
}
