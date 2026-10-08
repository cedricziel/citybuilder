import CityCore
import Foundation
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-age-signatures.

private let catalog = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/Sprites.style/catalog")

@Test("scenario: signature buildings are catalogued")
func scenarioSignatureBuildingsAreCatalogued() {
    let missing = BuildingKind.signatures.map { "building-\($0.rawValue)" }.filter {
        !FileManager.default.fileExists(atPath: catalog.appendingPathComponent("\($0).md").path)
    }
    #expect(BuildingKind.signatures.count == 5)
    #expect(missing.isEmpty, "missing: \(missing)")
}
