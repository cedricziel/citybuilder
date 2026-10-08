import Foundation
import SpriteKit
import Testing
@testable import CityCore
@testable import CityRender2D

// Scenarios from openspec/changes/add-culture-signatures.

private let resources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources")

@Test("scenario: culture signatures are catalogued")
func scenarioCultureSignaturesAreCatalogued() {
    let kinds = BuildingKind.cultureSignatures
    #expect(kinds.map(\.rawValue) == ["mead-hall", "forum", "temple-garden", "caravanserai"])
    let missingEntries = kinds.map { "Sprites.style/catalog/building-\($0.rawValue).md" }.filter {
        !FileManager.default.fileExists(atPath: resources.appendingPathComponent($0).path)
    }
    #expect(missingEntries.isEmpty, "missing catalog entries: \(missingEntries)")
    var sprites: [String] = []
    for kind in kinds {
        let base = "Buildings.atlas/building-\(kind.rawValue)"
        #expect(SpriteAnimation.entry(for: .buildingOperational(kind))?.frameCount == 2)
        sprites += [base] + (0 ..< 3).map { "\(base)-constructing-\($0)" } + (0 ..< 2).map { "\(base)-operational-\($0)" }
    }
    let missingSprites = sprites.filter {
        !FileManager.default.fileExists(atPath: resources.appendingPathComponent("\($0).png").path)
    }
    #expect(missingSprites.isEmpty, "missing sprites: \(missingSprites)")
}
