import CityCore
import Foundation
import Testing
@testable import CityRender2D

// The art of the wool → cloth chain (openspec/changes/add-wool-cloth-chain): the sheep farm and the
// weaver play their committed frames, and wool and cloth have the same status icons as every good.

private func worktreeRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CityRender2DTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // CityRender2D
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // worktree root
}

@Test("the weaver's wheel plays its four committed frames, the sheep farm its two")
func woolChainBuildingsPlayTheirFrames() throws {
    #expect(SpriteAnimation.entry(for: .buildingOperational(.weaver))?.frameCount == 4)
    #expect(SpriteAnimation.entry(for: .buildingOperational(.sheepFarm))?.frameCount == 2)
    let kit = worktreeRoot().appendingPathComponent("Resources/Kit.atlas")
    let files = try Set(FileManager.default.contentsOfDirectory(atPath: kit.path))
    for kind in [BuildingKind.sheepFarm, .weaver] {
        let frames = try #require(SpriteAnimation.entry(for: .buildingOperational(kind))?.frameCount)
        for frame in 0 ..< frames {
            let name = SpriteAnimation.assetName(for: .buildingOperational(kind), frame: frame)
            #expect(files.contains("\(name).png") && files.contains("\(name)@2x.png"), "\(name)")
        }
        for stage in 0 ..< 3 {
            #expect(files.contains("building-\(kind.rawValue)-constructing-\(stage).png"), "\(kind) stage \(stage)")
        }
        #expect(TextureFiltering.kitRenderedStems.contains("building-\(kind.rawValue)"))
    }
}

@Test("wool and cloth have a goods icon and both status icons, as every good does")
func woolAndClothHaveTheirIcons() throws {
    let kit = worktreeRoot().appendingPathComponent("Resources/Kit.atlas")
    let files = try Set(FileManager.default.contentsOfDirectory(atPath: kit.path))
    for good in [Good.wool, .cloth] {
        for name in ["good-\(good.rawValue)", "status-\(good.rawValue)-short", "status-\(good.rawValue)-stuck"] {
            #expect(files.contains("\(name).png") && files.contains("\(name)@2x.png"), "\(name)")
            #expect(TextureFiltering.kitRenderedStems.contains(name), "\(name)")
        }
    }
    #expect(StatusIcons.short(.wool) == "status-wool-short")
    #expect(StatusIcons.textureName(for: .missingInputs([.wool])) == "status-wool-short")
    #expect(StatusIcons.textureName(for: .outputStuck(.cloth)) == "status-cloth-stuck")
}
