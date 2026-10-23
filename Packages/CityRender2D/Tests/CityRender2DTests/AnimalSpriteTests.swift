import Foundation
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/realistic-walkers (animals).

@Test("scenario: Animal names route to Kit")
func scenarioAnimalNamesRouteToKit() {
    for name in ["animal-sheep-graze-sw-2", "animal-hen-ne-0"] {
        #expect(SpriteAtlasRouting.atlasName(for: name) == SpriteAtlasRouting.kitAtlasName, "\(name)")
        #expect(TextureFiltering.mode(for: name) == .linear, "\(name)")
    }
}

@Test("scenario: Sheep grazing has four frames")
func scenarioSheepGrazingHasFourFrames() {
    let key = SpriteAnimation.AnimationKey.animal(.sheepGraze, .sw)
    #expect(SpriteAnimation.entry(for: key)?.frameCount == 4)
    #expect((0 ..< 4).map { SpriteAnimation.assetName(for: key, frame: $0) }
        == ["animal-sheep-graze-sw-0", "animal-sheep-graze-sw-1", "animal-sheep-graze-sw-2", "animal-sheep-graze-sw-3"])
    #expect(SpriteAnimation.entry(for: .animal(.cowWalk, .ne))?.frameCount == 8)
    #expect(SpriteAnimation.entry(for: .animal(.hen, .se))?.frameCount == 4)
}

/// The renderer's anchors and the brief's `Anchor:` lines (from the IsoKit pens) must agree.
@Test("animals anchor at the feet the brief names")
func animalsAnchorWhereTheBriefSays() throws {
    let brief = try String(
        contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Sprites.style/catalog/animal.md"),
        encoding: .utf8
    )
    for (animal, action) in [("sheep", SpriteAtlas.AnimalAction.sheepWalk), ("cow", .cowGraze), ("hen", .hen)] {
        let line = try #require(brief.split(separator: "\n").first { $0.hasPrefix("- Anchor \(animal):") })
        let numbers = line.split(whereSeparator: { !"0123456789".contains($0) }).compactMap { Double($0) }
        try #require(numbers.count == 4, "\(line)")
        #expect(abs(action.anchor.x - numbers[0] / numbers[2]) < 0.0001, "\(line)")
        #expect(abs(action.anchor.y - numbers[1] / numbers[3]) < 0.0001, "\(line)")
    }
}
