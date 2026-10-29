#if canImport(AppKit)
import Foundation
import Testing
@testable import CityCore
@testable import CityRender2D

// add-event-counterplay task 8.1: the fire watch, granary, ruins, fire effect, watchman and event
// status icons are drawn and committed.

private func kitAtlas() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/Kit.atlas")
}

private func committed(_ name: String) -> Bool {
    ["\(name).png", "\(name)@2x.png"].allSatisfy {
        FileManager.default.fileExists(atPath: kitAtlas().appendingPathComponent($0).path)
    }
}

@Test("ruins are drawn per footprint: 2 x 2 is the plain name")
func ruinsAreNamedByFootprint() {
    #expect(SpriteAtlas.ruinsName(footprint: Footprint(width: 2, height: 2)) == "building-ruins")
    #expect(SpriteAtlas.ruinsName(footprint: Footprint(width: 1, height: 1)) == "building-ruins-1x1")
    #expect(SpriteAtlas.ruinsName(footprint: Footprint(width: 3, height: 3)) == "building-ruins-3x3")
}

@Test("every footprint that can burn has its ruins committed")
func everyFlammableFootprintHasRuins() {
    let footprints = Set(BuildingKind.allCases.filter(World.isFlammable).map { BuildingCatalog.spec(for: $0).footprint })
    #expect(!footprints.isEmpty)
    let missing = footprints.map(SpriteAtlas.ruinsName).filter { !committed($0) }
    #expect(missing.isEmpty, "\(missing)")
    #expect(footprints.allSatisfy { SpriteAtlas.ruinSides.contains($0.width) && $0.width == $0.height })
}

@Test("the fire effect, the watchman and the event icons are committed")
func eventSpritesAreCommitted() {
    let fire = (0 ..< 3).map { SpriteAnimation.assetName(for: .fire, frame: $0) }
    let watchman = SpriteAtlas.WalkerFacing.allCases.flatMap { facing in
        (0 ..< 8).map { SpriteAnimation.assetName(for: .watchman(facing), frame: $0) }
    }
    let icons = ["burning", "ruins", "blight", "fever"].map { "status-\($0)" }
    let names = ["building-fire-watch", "building-granary"] + fire + watchman + icons
    #expect(names.filter { !committed($0) }.isEmpty)
    #expect(fire.allSatisfy { SpriteAtlasRouting.atlasName(for: $0) == SpriteAtlasRouting.kitAtlasName })
}
#endif
