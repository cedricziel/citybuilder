import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/realistic-walkers.

private let looks = SpriteAtlas.WalkerLook.allCases

/// Tests/CityRender2DTests/<file> -> worktree root.
private func worktreeRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
}

/// Every people frame the renderer can request: each resident look and carrier load, in every facing.
private func peopleNamesTheRendererRequests() -> [String] {
    SpriteAnimation.AnimationKey.people.flatMap { key in
        (0 ..< (SpriteAnimation.entry(for: key)?.frameCount ?? 0)).map { SpriteAnimation.assetName(for: key, frame: $0) }
    }
}

@Test("scenario: Worker and variant names route to Kit")
func scenarioWalkerNamesRouteToKit() {
    for name in ["walker-se-3", "walker-woman-nw-7", "carrier-logs-nw-7"] {
        #expect(SpriteAtlasRouting.atlasName(for: name) == SpriteAtlasRouting.kitAtlasName, "\(name)")
        #expect(TextureFiltering.mode(for: name) == .linear, "\(name)")
    }
}

@Test("scenario: The default variant is the worker")
func scenarioDefaultVariantIsTheWorker() {
    #expect(SpriteAnimation.assetName(for: .walker(.se), frame: 7) == "walker-se-7")
    #expect(SpriteAnimation.assetName(for: .walker(.se, .worker), frame: 7) == "walker-se-7")
    #expect(SpriteAnimation.assetName(for: .walker(.nw, .woman), frame: 3) == "walker-woman-nw-3")
    let gait = SpriteAnimation.Entry(frameCount: 8, timePerFrame: 0.1, loop: .forever)
    #expect(SpriteAnimation.entry(for: .walker(.se)) == gait)
    #expect(SpriteAnimation.entry(for: .walker(.sw, .woman)) == gait)
    #expect(SpriteAnimation.entry(for: .carrier(.logs, .ne)) == gait)
}

@Test("scenario: Every walker frame is catalogued")
func scenarioEveryWalkerFrameIsCatalogued() {
    let names = peopleNamesTheRendererRequests()
    #expect(names.count == (looks.count + CarrierLoad.allCases.count) * 4 * 8)
    let catalogued = Set(SpriteAtlas.catalogSpriteNames)
    #expect(names.filter { !catalogued.contains($0) }.isEmpty)
}

/// The reverse of the catalog check: every people frame is committed, at both scales, where it routes.
@Test("scenario: Every variant and facing has eight gait frames")
func scenarioEveryPeopleFrameIsOnDisk() {
    let resources = worktreeRoot().appendingPathComponent("Resources")
    let missing = peopleNamesTheRendererRequests().flatMap { name -> [String] in
        let atlas = SpriteAtlasRouting.atlasName(for: name) ?? "?"
        return ["\(name).png", "\(name)@2x.png"].compactMap { file in
            let path = resources.appendingPathComponent("\(atlas).atlas/\(file)").path
            return FileManager.default.fileExists(atPath: path) ? nil : "\(atlas).atlas/\(file)"
        }
    }
    #expect(missing.isEmpty, "\(missing)")
    #expect(!FileManager.default.fileExists(atPath: resources.appendingPathComponent("Units.atlas").path))
}
