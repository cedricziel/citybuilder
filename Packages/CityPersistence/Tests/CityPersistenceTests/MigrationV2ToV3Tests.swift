import Foundation
import Testing
@testable import CityCore
@testable import CityPersistence

// Tests for the v2 → v3 save migration added by
// `add-construction-stalls` → M7.

private func decodeWorld(_ data: Data) throws -> World {
    let store = SaveStore(baseDirectory: FileManager.default.temporaryDirectory)
    return try store.decode(data)
}

/// Build a synthetic v2 payload by encoding a current World, then
/// stamping the version back to 2 and stripping construction-stalls
/// fields so the migration has work to do.
private func makeV2Payload(world: World) throws -> Data {
    var data = try JSONEncoder().encode(SaveFile(world: world))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    json["version"] = 2
    var inner = json["world"] as? [String: Any] ?? [:]
    if var buildings = inner["buildings"] as? [Any] {
        for idx in stride(from: 1, to: buildings.count, by: 2) {
            if var building = buildings[idx] as? [String: Any] {
                building.removeValue(forKey: "constructionState")
                building.removeValue(forKey: "materialsDelivered")
                buildings[idx] = building
            }
        }
        inner["buildings"] = buildings
    }
    json["world"] = inner
    data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    return data
}

@Test("scenario: v2 save with constructing buildings migrates to actively with full materialsdelivered")
func scenarioV2SaveWithConstructingBuildingsMigrates() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let id = EntityID(raw: 1001)
    world.buildings[id] = Building(
        id: id, kind: .sawmill,
        anchor: TileCoordinate(x: 1, y: 1),
        state: .constructing,
        ticksSincePlacement: 5,
        constructionState: .waitingForMaterials,
        materialsDelivered: [:]
    )
    let data = try makeV2Payload(world: world)
    let loaded = try decodeWorld(data)
    let migrated = try #require(loaded.buildings[id])
    #expect(migrated.constructionState == .actively)
    let expected = BuildingCatalog.spec(for: .sawmill).materialCost
    #expect(migrated.materialsDelivered == expected)
}

@Test("scenario: v2 save with operational buildings ignores new fields")
func scenarioV2SaveWithOperationalBuildingsIgnoresNewFields() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let id = EntityID(raw: 1001)
    world.buildings[id] = Building(
        id: id, kind: .lumberjackHut,
        anchor: TileCoordinate(x: 1, y: 1),
        state: .operational,
        ticksSincePlacement: 30
    )
    let data = try makeV2Payload(world: world)
    let loaded = try decodeWorld(data)
    let migrated = try #require(loaded.buildings[id])
    #expect(migrated.state == .operational)
    #expect(migrated.constructionState == .actively)
    #expect(migrated.materialsDelivered.isEmpty)
}

@Test("scenario: v3 save round-trips through codable")
func scenarioV3SaveRoundTripsThroughCodable() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let id = EntityID(raw: 1001)
    world.buildings[id] = Building(
        id: id, kind: .sawmill,
        anchor: TileCoordinate(x: 1, y: 1),
        state: .constructing,
        ticksSincePlacement: 0,
        constructionState: .waitingForMaterials,
        materialsDelivered: [.wood: 2]
    )
    let data = try JSONEncoder().encode(SaveFile(world: world))
    let loaded = try decodeWorld(data)
    let restored = try #require(loaded.buildings[id])
    #expect(restored.constructionState == .waitingForMaterials)
    #expect(restored.materialsDelivered[.wood] == 2)
}
