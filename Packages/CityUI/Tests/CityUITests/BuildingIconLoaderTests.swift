import CityCore
import CityRender2D
import Testing
@testable import CityUI

@Test("building icons use the atlas texture names")
func buildingIconsUseTheAtlasTextureNames() {
    #expect(BuildingIconLoader.textureName(for: .house) == "building-house")
    #expect(BuildingIconLoader.textureName(for: .lumberjackHut) == "building-lumberjack-hut")
    #expect(BuildingIconLoader.textureName(for: .port) == "building-port-s")
    #expect(BuildingIconLoader.textureName(for: .shipyard) == "building-shipyard-s")
}

@Test("kit-rendered building icons scale smoothly, pixel art stays crisp")
func kitIconsScaleSmoothly() {
    #expect(BuildingIconLoader.interpolation(for: .house) == .high)
    #expect(BuildingIconLoader.interpolation(for: .townCenter) == .high)
    if let legacy = legacyKind {
        #expect(BuildingIconLoader.interpolation(for: legacy) == GoodIconLoader.pixelArtInterpolation)
    }
}

/// Any building kind still drawn as legacy pixel art, or nil once every family is on the kit; so the
/// tests don't break each time a family migrates.
private let legacyKind = BuildingKind.allCases.first {
    !TextureFiltering.kitRenderedStems.contains(TextureFiltering.stem(of: BuildingIconLoader.textureName(for: $0)))
}

@Test("building icons come from the atlas their sprite routes to")
func buildingIconsUseSpriteRouting() {
    #expect(BuildingIconLoader.atlasName(for: .house) == "Kit")
    if let legacy = legacyKind {
        #expect(BuildingIconLoader.atlasName(for: legacy) == "Buildings")
    }
}

@Test("building icons fall back to a symbol")
func buildingIconsFallBackToASymbol() {
    #expect(BuildingIconLoader.fallbackSymbolName(for: .road) == "road.lanes")
    #expect(BuildingIconLoader.fallbackSymbolName(for: .house) == "building.2.fill")
}

@MainActor
@Test("building icons are cached per kind")
func buildingIconsAreCachedPerKind() {
    _ = BuildingIconLoader.image(for: .monument)
    #expect(BuildingIconLoader.cachedKinds.contains(.monument))
}
