import SpriteKit
import Testing
@testable import CityRender2D

/// rendering-2_5d: World textures are @2x and linearly filtered (design D7).
struct TextureFilteringTests {
    private let houses: Set<String> = ["building-house", "terrain-grass"]

    @Test("scenario: Building textures filter linearly")
    func buildingTexturesFilterLinearly() {
        #expect(TextureFiltering.mode(for: "building-house", kitRendered: houses) == .linear)
        #expect(TextureFiltering.mode(for: "building-house-tier2", kitRendered: houses) == .linear)
        #expect(TextureFiltering.mode(for: "building-house-constructing-1", kitRendered: houses) == .linear)
        #expect(TextureFiltering.mode(for: "terrain-grass-beach-t3", kitRendered: houses) == .linear)
    }

    @Test("scenario: Goods icons stay pixel art")
    func goodsIconsStayPixelArt() {
        let everything: Set = ["good-wood", "overlay-waiting-materials"]
        #expect(TextureFiltering.mode(for: "good-wood", kitRendered: everything) == .nearest)
        #expect(TextureFiltering.mode(for: "overlay-waiting-materials", kitRendered: everything) == .nearest)
    }

    @Test("legacy pixel art stays nearest until its family migrates")
    func legacyStaysNearest() {
        #expect(TextureFiltering.mode(for: "building-bakery", kitRendered: houses) == .nearest)
        #expect(TextureFiltering.mode(for: "building-houses-of-parliament", kitRendered: houses) == .nearest)
        #expect(TextureFiltering.mode(for: "walker-se-0", kitRendered: houses) == .nearest)
    }
}
