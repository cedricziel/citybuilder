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

/// Every frame the renderer can request for `keys`.
private func names(_ keys: [SpriteAnimation.AnimationKey]) -> [String] {
    keys.flatMap { key in
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
    #expect(names(SpriteAnimation.AnimationKey.people).count == (looks.count + CarrierLoad.allCases.count + 1) * 4 * 8)
    #expect(names(SpriteAnimation.AnimationKey.animals).count == 4 * (8 + 4 + 8 + 4 + 4))
    let catalogued = Set(SpriteAtlas.catalogSpriteNames)
    #expect(names(SpriteAnimation.AnimationKey.figures).filter { !catalogued.contains($0) }.isEmpty)
}

/// The reverse of the catalog check: every people and animal frame is committed, at both scales, where it routes.
@Test("scenario: Every variant and facing has eight gait frames")
func scenarioEveryPeopleFrameIsOnDisk() {
    let resources = worktreeRoot().appendingPathComponent("Resources")
    let missing = names(SpriteAnimation.AnimationKey.figures).flatMap { name -> [String] in
        let atlas = SpriteAtlasRouting.atlasName(for: name) ?? "?"
        return ["\(name).png", "\(name)@2x.png"].compactMap { file in
            let path = resources.appendingPathComponent("\(atlas).atlas/\(file)").path
            return FileManager.default.fileExists(atPath: path) ? nil : "\(atlas).atlas/\(file)"
        }
    }
    #expect(missing.isEmpty, "\(missing)")
    #expect(!FileManager.default.fileExists(atPath: resources.appendingPathComponent("Units.atlas").path))
}

@MainActor
@Test("scenario: A carrier stands on its tile")
func scenarioCarrierStandsOnItsTile() throws {
    let base = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1).snapshot()
    let carrier = Carrier(
        id: EntityID(raw: 7),
        path: [TileCoordinate(x: 2, y: 1), TileCoordinate(x: 1, y: 1)],
        mission: .deliver(good: .wine, amount: 1, fromProducer: EntityID(raw: 1), toWarehouse: EntityID(raw: 2))
    )
    let snapshot = WorldSnapshot(
        tickCount: 1, simulatedTime: base.simulatedTime, mapWidth: 10, mapHeight: 10,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: [:], carriers: [carrier],
        economy: base.economy, totalPopulation: 0, camera: base.camera
    )
    let scene = IsoWorldScene()
    scene.reconcileCarriers(with: snapshot, now: 0)
    let node = try #require(scene.carrierVisuals[EntityID(raw: 7)]?.node)
    // SpriteKit stores the anchor as Float.
    #expect(abs(node.anchorPoint.x - 12.0 / 32.0) < 0.0001 && abs(node.anchorPoint.y - 5.0 / 32.0) < 0.0001)
    #expect(node.xScale > 0)
}

@Test("scenario: A stroller heading down-left faces south-west")
func scenarioStrollerFacesItsWay() {
    let stroller = StrollerPlanner.Stroller(
        house: EntityID(raw: 1), slot: 0, from: TileCoordinate(x: 3, y: 3), to: TileCoordinate(x: 3, y: 4), progress: 0.5
    )
    #expect(stroller.facing == .sw)
    let back = StrollerPlanner.Stroller(
        house: EntityID(raw: 1), slot: 0, from: TileCoordinate(x: 3, y: 3), to: TileCoordinate(x: 2, y: 3), progress: 0.5
    )
    #expect(back.facing == .nw)
}
