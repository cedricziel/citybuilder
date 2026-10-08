import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-cultures.

private func spec(_ kind: BuildingKind, state: BuildingState, size: Int, tier: HouseTier = .peasants) -> SpriteSpec {
    SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: kind, state: state, footprint: Footprint(width: size, height: size),
            constructionFrameIndex: state == .constructing ? 0 : nil, orientation: nil,
            isWaitingForMaterials: false, houseTier: tier
        )
    )
}

@MainActor
private func textureName(_ spec: SpriteSpec, culture: Culture) -> String? {
    let scene = IsoWorldScene()
    scene.culture = culture
    scene.hasSprite = { _ in true }
    return scene.makeBuildingNode(for: spec).userData?[IsoWorldScene.textureNameKey] as? String
}

@MainActor
@Test("scenario: east asian town center")
func scenarioEastAsianTownCenter() {
    #expect(textureName(spec(.townCenter, state: .operational, size: 3), culture: .eastAsian)
        == "building-town-center-east-asian")
}

@MainActor
@Test("scenario: shared fallback")
func scenarioSharedFallback() {
    #expect(textureName(spec(.sawmill, state: .operational, size: 2), culture: .eastAsian) == nil)
}

@MainActor
@Test("scenario: construction stays shared")
func scenarioConstructionStaysShared() {
    #expect(textureName(spec(.house, state: .constructing, size: 2), culture: .middleEastern) == nil)
}

@MainActor
@Test("mediterranean merchant house uses its culture tier sprite")
func mediterraneanMerchantHouseUsesItsCultureTierSprite() {
    #expect(textureName(spec(.house, state: .operational, size: 2, tier: .merchants), culture: .mediterranean)
        == "building-house-tier3-mediterranean")
}

@MainActor
@Test("northern european keeps the shared names")
func northernEuropeanKeepsTheSharedNames() {
    #expect(textureName(spec(.townCenter, state: .operational, size: 3), culture: .northernEuropean) == nil)
}

// Scenarios from openspec/changes/add-historical-ages.

@MainActor
private func houseTextureName(tier: HouseTier, culture: Culture, age: Age) -> String? {
    let scene = IsoWorldScene()
    scene.culture = culture
    scene.age = age
    scene.hasSprite = { _ in true }
    return scene.makeBuildingNode(for: spec(.house, state: .operational, size: 2, tier: tier))
        .userData?[IsoWorldScene.textureNameKey] as? String
}

@MainActor
@Test("scenario: industrial mediterranean citizens")
func scenarioIndustrialMediterraneanCitizens() {
    #expect(houseTextureName(tier: .citizens, culture: .mediterranean, age: .industrial)
        == "building-house-tier2-industrial-mediterranean")
}

@MainActor
@Test("scenario: medieval names are unchanged")
func scenarioMedievalNamesAreUnchanged() {
    #expect(houseTextureName(tier: .peasants, culture: .northernEuropean, age: .medieval) == nil)
}

@Test("house look names fall back from age and culture to culture")
func houseLookNamesFallBack() {
    #expect(IsoWorldScene.houseLookNames(houseTier: .merchants, culture: .eastAsian, age: .modern) == [
        "building-house-tier3-modern-east-asian", "building-house-tier3-modern", "building-house-tier3-east-asian"
    ])
}

@Test("scenario: every culture variant is catalogued")
func scenarioEveryCultureVariantIsCatalogued() {
    let catalog = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Sprites.style/catalog")
    var missing: [String] = []
    for culture in Culture.allCases where culture != .northernEuropean {
        for kind in IsoWorldScene.cultureVariantKinds {
            let id = "building-\(kind.rawValue)-\(culture.rawValue)"
            if !FileManager.default.fileExists(atPath: catalog.appendingPathComponent("\(id).md").path) {
                missing.append(id)
            }
        }
    }
    #expect(IsoWorldScene.cultureVariantKinds.count * 3 == 12)
    #expect(missing.isEmpty, "missing: \(missing)")
}
