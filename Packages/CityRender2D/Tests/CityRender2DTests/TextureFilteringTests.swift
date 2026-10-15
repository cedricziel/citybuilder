import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

/// rendering-2_5d: World textures are @2x and linearly filtered (design D7).
struct TextureFilteringTests {
    private let houses: Set<String> = ["building-house", "building-house-tier2", "terrain-grass-beach"]

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

    @Test("a migrated house does not make its legacy culture variants linear")
    func cultureVariantsStayNearest() {
        #expect(TextureFiltering.mode(for: "building-house-mediterranean", kitRendered: houses) == .nearest)
        #expect(TextureFiltering.mode(for: "building-house-modern-east-asian", kitRendered: houses) == .nearest)
        #expect(TextureFiltering.mode(for: "building-house-tier3-renaissance", kitRendered: houses) == .nearest)
        #expect(TextureFiltering.mode(for: "building-bakery", kitRendered: houses) == .nearest)
        #expect(TextureFiltering.mode(for: "walker-se-0", kitRendered: houses) == .nearest)
    }

    @Test("stems drop states, frames, variants and transition masks only")
    func stems() {
        #expect(TextureFiltering.stem(of: "building-sawmill-operational-2") == "building-sawmill")
        #expect(TextureFiltering.stem(of: "building-house-constructing-0") == "building-house")
        #expect(TextureFiltering.stem(of: "terrain-grass-beach-t3-1") == "terrain-grass-beach")
        #expect(TextureFiltering.stem(of: "terrain-mountain-v2") == "terrain-mountain")
        #expect(TextureFiltering.stem(of: "building-house-tier2") == "building-house-tier2")
        #expect(TextureFiltering.stem(of: "building-house-modern-east-asian") == "building-house-modern-east-asian")
    }

    /// One source of truth: the shipped set is exactly the stems the migrated briefs list.
    @Test("the linear-filter list matches the catalog's migrated briefs")
    func listMatchesCatalog() throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Sprites.style/catalog")
        var expected: Set<String> = []
        let files = try FileManager.default.contentsOfDirectory(at: catalog, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "md" {
            let text = try String(contentsOf: file, encoding: .utf8)
            guard text.hasPrefix("---\nsource = \"isokit\"\n") || text.hasPrefix("---\nsource = \"svg\"\n") else { continue }
            for line in text.components(separatedBy: "\n") where line.hasPrefix("- (") {
                let parts = line.components(separatedBy: "`")
                if parts.count > 2 { expected.insert(TextureFiltering.stem(of: parts[1])) }
            }
        }
        #expect(TextureFiltering.kitRenderedStems == expected)
    }
}
