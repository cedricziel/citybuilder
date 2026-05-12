import Foundation
import Testing
@testable import CityCore

// Tests for the construction substate added by
// `add-construction-stalls` → M1.

@Test("scenario: fresh building defaults to actively constructing")
func scenarioFreshBuildingDefaultsToActivelyConstructing() {
    let building = Building(
        id: EntityID(raw: 1),
        kind: .lumberjackHut,
        anchor: TileCoordinate(x: 0, y: 0)
    )
    #expect(building.constructionState == .actively)
    #expect(building.materialsDelivered.isEmpty)
}

@Test("scenario: constructionstate round-trips through codable")
func scenarioConstructionStateRoundTripsThroughCodable() throws {
    let building = Building(
        id: EntityID(raw: 7),
        kind: .sawmill,
        anchor: TileCoordinate(x: 1, y: 2),
        constructionState: .waitingForMaterials
    )
    let encoded = try JSONEncoder().encode(building)
    let decoded = try JSONDecoder().decode(Building.self, from: encoded)
    #expect(decoded.constructionState == .waitingForMaterials)
}

@Test("scenario: materialsdelivered round-trips through codable")
func scenarioMaterialsDeliveredRoundTripsThroughCodable() throws {
    let building = Building(
        id: EntityID(raw: 9),
        kind: .sawmill,
        anchor: TileCoordinate(x: 3, y: 3),
        materialsDelivered: [.wood: 2, .planks: 1]
    )
    let encoded = try JSONEncoder().encode(building)
    let decoded = try JSONDecoder().decode(Building.self, from: encoded)
    #expect(decoded.materialsDelivered[.wood] == 2)
    #expect(decoded.materialsDelivered[.planks] == 1)
}
