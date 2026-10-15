import CityCore
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
    #expect(BuildingIconLoader.interpolation(for: .warehouse) == GoodIconLoader.pixelArtInterpolation)
}

@Test("building icons come from the atlas their sprite routes to")
func buildingIconsUseSpriteRouting() {
    #expect(BuildingIconLoader.atlasName(for: .house) == "Kit")
    #expect(BuildingIconLoader.atlasName(for: .warehouse) == "Buildings")
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
