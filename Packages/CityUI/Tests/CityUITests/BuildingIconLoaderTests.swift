import CityCore
import CityRender2D
import CoreGraphics
import Foundation
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
}

/// Every building family is on the art kit, so every kind's icon is a linearly filtered kit render.
@Test("every building icon is a kit render")
func everyBuildingIconIsAKitRender() {
    let pixelArt = BuildingKind.allCases.filter { BuildingIconLoader.interpolation(for: $0) != .high }
    #expect(pixelArt.isEmpty, "\(pixelArt)")
}

@Test("building icons come from the atlas their sprite routes to")
func buildingIconsUseSpriteRouting() {
    #expect(BuildingIconLoader.atlasName(for: .house) == "Kit")
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

private func bitmap(width: Int, height: Int) -> CGContext? {
    CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

/// Sprites carry a transparent margin for their shadow; the icon is cut to the building so it fills its slot.
@Test("building icons are cut to their opaque pixels")
func iconsAreCutToTheirOpaquePixels() throws {
    let context = try #require(bitmap(width: 40, height: 20))
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(x: 5, y: 3, width: 10, height: 6))
    let cropped = try BuildingIconLoader.croppedToOpaque(#require(context.makeImage()))
    #expect(cropped.width == 10 && cropped.height == 6)
    let empty = try #require(bitmap(width: 4, height: 4)?.makeImage())
    #expect(BuildingIconLoader.croppedToOpaque(empty).width == 4)
}
