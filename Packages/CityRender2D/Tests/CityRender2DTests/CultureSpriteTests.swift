import CityCore
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
