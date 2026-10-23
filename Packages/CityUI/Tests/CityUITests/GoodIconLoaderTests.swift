import CityCore
import CityRender2D
import Foundation
import SwiftUI
import Testing
@testable import CityUI

// Tests for the SwiftUI good-icon bridge added by
// `add-island-hud-overlay` → M5. Scenarios from
// openspec/changes/add-island-hud-overlay/specs/rendering-2_5d/spec.md
// + design D6.

@Test("scenario: good icon loader resolves a known good")
func scenarioGoodIconLoaderResolvesAKnownGood() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("good-icon-loader-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("good-wood.png")
    // Tiny 1×1 placeholder PNG signature — enough for the resolver
    // path; the loader only opens it when reading the actual image.
    try Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).write(to: url)

    let origin = GoodIconLoader.origin(for: .wood) { good in
        guard good == .wood else { return nil }
        return url
    }
    #expect(origin == .loaded(url))
}

@Test("scenario: missing icon returns the sf symbol fallback")
func scenarioMissingIconReturnsTheSFSymbolFallback() {
    let origin = GoodIconLoader.origin(for: .food) { _ in nil }
    #expect(origin == .fallback)
    // The fallback symbol name is the documented sentinel — the chip
    // renderer reads it to decide which Image to display.
    #expect(GoodIconLoader.fallbackSymbolName == "cube.fill")
}

@Test("scenario: Goods icon scales smoothly")
func scenarioGoodsIconScalesSmoothly() {
    // The icons are anti-aliased SVG renders: the loader and the HUD's
    // good chips draw them with high-quality interpolation, not the
    // nearest-neighbor mode kept for pixel art.
    #expect(GoodIconLoader.interpolation == .high)
    #expect(GoodIconLoader.interpolation != GoodIconLoader.pixelArtInterpolation)
}

@Test("the goods icons come from the Kit atlas")
func goodsIconsComeFromTheKitAtlas() {
    #expect(GoodIconLoader.atlasName == SpriteAtlasRouting.atlasName(for: "good-wood"))
}

@Test("scenario: image factory never returns nil")
func scenarioImageFactoryNeverReturnsNil() {
    // Resolver returns nil → loader falls back to SF Symbol; the
    // factory function always returns a usable Image.
    _ = GoodIconLoader.image(for: .planks) { _ in nil }
    // Successful resolver path is exercised by the resolves test above.
}
