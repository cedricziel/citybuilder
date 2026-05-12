import Foundation
import Testing
@testable import CityCore

// Tests for the materialsDeducted event added by
// `add-build-materials-cost` → M4.

@Test("scenario: successful placement emits materialsdeducted")
func scenarioSuccessfulPlacementEmitsMaterialsDeducted() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    world.economy.credit(10000)
    world.pendingCommands.append(.place(.lumberjackHut, at: TileCoordinate(x: 1, y: 1)))
    let result = world.tick()
    let materialEvents = result.events.filter {
        if case .materialsDeducted = $0 { return true }
        return false
    }
    #expect(!materialEvents.isEmpty, "expected materialsDeducted event after lumberjack placement")
}

@Test("scenario: materialsdeducted carries the per-good amounts")
func scenarioMaterialsDeductedCarriesThePerGoodAmounts() throws {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    world.economy.credit(10000)
    world.pendingCommands.append(.place(.sawmill, at: TileCoordinate(x: 1, y: 1)))
    let result = world.tick()
    var deducted: [Good: Int]?
    for event in result.events {
        if case let .materialsDeducted(_, cost) = event {
            deducted = cost
            break
        }
    }
    let cost = try #require(deducted)
    #expect(cost[.wood] == 4)
    #expect(cost[.planks] == 1)
}

@Test("scenario: free-of-materials placement emits no materialsdeducted")
func scenarioFreeOfMaterialsPlacementEmitsNoMaterialsDeducted() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    world.economy.credit(10000)
    world.pendingCommands.append(.place(.road, at: TileCoordinate(x: 1, y: 1)))
    let result = world.tick()
    let any = result.events.contains {
        if case .materialsDeducted = $0 { return true }
        return false
    }
    #expect(!any, "road placement has no material cost — event must not fire")
}
