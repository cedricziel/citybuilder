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
