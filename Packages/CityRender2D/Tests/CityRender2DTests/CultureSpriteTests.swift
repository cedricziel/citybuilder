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

private let resources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources")
private let catalog = resources.appendingPathComponent("Sprites.style/catalog")

@Test("scenario: every culture variant is catalogued")
func scenarioEveryCultureVariantIsCatalogued() {
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

@Test("scenario: every age house is catalogued")
func scenarioEveryAgeHouseIsCatalogued() {
    var ids = ["building-quern-house"]
    for age in Age.allCases where age != .medieval {
        for culture in Culture.allCases {
            ids.append(culture == .northernEuropean ? "building-house-\(age.rawValue)"
                : "building-house-\(age.rawValue)-\(culture.rawValue)")
        }
    }
    let missing = ids.filter { !FileManager.default.fileExists(atPath: catalog.appendingPathComponent("\($0).md").path) }
    #expect(missing.isEmpty, "missing: \(missing)")
}

// Scenarios from openspec/changes/add-culture-content.

@Test("scenario: culture content is catalogued")
func scenarioCultureContentIsCatalogued() {
    let kinds = BuildingKind.allCases.filter { $0.culture != nil && !$0.isCultureSignature }
    let goods: [Good] = [.hops, .beer, .grapes, .wine, .teaLeaves, .tea, .coffeeCherries, .coffee]
    #expect(kinds.count == 8)
    let ids = kinds.map { "building-\($0.rawValue)" } + goods.map { "good-\($0.rawValue)" }
    let missingEntries = ids.filter {
        !FileManager.default.fileExists(atPath: catalog.appendingPathComponent("\($0).md").path)
    }
    #expect(missingEntries.isEmpty, "missing catalog entries: \(missingEntries)")
    var sprites = goods.map { "Icons.atlas/good-\($0.rawValue)" }
    for kind in kinds {
        let base = "Buildings.atlas/building-\(kind.rawValue)"
        let frames = SpriteAnimation.entry(for: .buildingOperational(kind))?.frameCount ?? 0
        #expect(frames == 2, "\(kind) has no operational animation")
        sprites.append(base)
        sprites += (0 ..< 3).map { "\(base)-constructing-\($0)" }
        sprites += (0 ..< frames).map { "\(base)-operational-\($0)" }
    }
    let missingSprites = sprites.filter {
        !FileManager.default.fileExists(atPath: resources.appendingPathComponent("\($0).png").path)
    }
    #expect(missingSprites.isEmpty, "missing sprites: \(missingSprites)")
}
