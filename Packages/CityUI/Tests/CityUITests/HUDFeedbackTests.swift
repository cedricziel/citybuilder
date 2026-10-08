import CityCore
import Foundation
import SpriteKit
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import CityUI

// Scenarios from openspec/changes/fix-playable-foundation/specs/platform-shells.

private let enUS = Locale(identifier: "en_US")

// MARK: - Placement rejection feedback

@Test("scenario: material shortfall message names the missing goods")
func scenarioMaterialShortfallMessageNamesTheMissingGoods() {
    #expect(PlacementRejectionText.message(for: .insufficientMaterials([.planks: 2])) == "Needs 2 more planks")
    #expect(
        PlacementRejectionText.message(for: .insufficientMaterials([.planks: 1, .wood: 3]))
            == "Needs 3 more wood, 1 more planks"
    )
}

@Test("scenario: occupied tile message")
func scenarioOccupiedTileMessage() {
    #expect(PlacementRejectionText.message(for: .tileOccupied) == "Tile occupied")
}

@Test("scenario: rejection message expires")
func scenarioRejectionMessageExpires() {
    let hud = HUDViewModel()
    let start = Date(timeIntervalSinceReferenceDate: 1000)
    hud.showRejection(.tileOccupied, now: start)
    #expect(hud.rejectionMessage(at: start.addingTimeInterval(1)) == "Tile occupied")
    #expect(hud.rejectionMessage(at: start.addingTimeInterval(2.5)) == nil)
}

@Test("newer rejection replaces the older one")
func newerRejectionReplacesOlder() {
    let hud = HUDViewModel()
    let start = Date(timeIntervalSinceReferenceDate: 1000)
    hud.showRejection(.tileOccupied, now: start)
    hud.showRejection(.terrainNotBuildable, now: start.addingTimeInterval(2))
    #expect(hud.rejectionMessage(at: start.addingTimeInterval(3)) == "Can't build on water")
}

@MainActor
@Test("tapping an occupied tile shows feedback and enqueues nothing")
func tappingOccupiedTileShowsFeedback() throws {
    let world = World.newGame()
    let townCenter = try #require(world.buildings.values.first { $0.kind == .townCenter })
    let session = GameSession(world: world)
    session.selectTool(.place(.house))

    session.handleTap(at: townCenter.anchor)

    #expect(session.hud.rejectionMessage(at: Date()) == "Tile occupied")
    #expect(session.world.pendingCommands.isEmpty)
}

// MARK: - Atlas-backed good icons

/// A 4×4 opaque image in the platform type SKTextureAtlas(dictionary:)
/// accepts.
private func tinyImage() throws -> Any {
    let context = try #require(CGContext(
        data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    let cgImage = try #require(context.makeImage())
    #if canImport(UIKit)
    return UIImage(cgImage: cgImage)
    #else
    return NSImage(cgImage: cgImage, size: NSSize(width: 4, height: 4))
    #endif
}

@Test("scenario: bundled good icon resolves from the compiled atlas")
func scenarioBundledGoodIconResolvesFromTheCompiledAtlas() throws {
    let atlas = try SKTextureAtlas(dictionary: ["good-wood": tinyImage()])
    #expect(GoodIconLoader.origin(for: .wood, atlas: atlas) == .atlas(name: GoodIconLoader.atlasName))
}

@Test("scenario: missing good icon falls back to the symbol")
func scenarioMissingGoodIconFallsBackToTheSymbol() {
    let atlas = SKTextureAtlas(dictionary: [String: Any]())
    #expect(GoodIconLoader.origin(for: .food, atlas: atlas) == .fallback)
}

// MARK: - Compact labels

@Test("scenario: compact money value uses grouped digits")
func scenarioCompactMoneyValueUsesGroupedDigits() {
    let hud = HUDViewModel(money: 1000)
    #expect(hud.formattedMoney(locale: enUS) == "$1,000")
}

@Test("scenario: compact layout limits labels to one line")
func scenarioCompactLayoutLimitsLabelsToOneLine() {
    let labels = LayoutDecisions.decisions(for: .compact).labels
    #expect(labels.statValueLineLimit == 1)
    #expect(labels.statCaptionLineLimit == 1)
    #expect(labels.paletteLabelLineLimit == 1)
}

@Test("compiled atlas texture names carry the png extension")
func compiledAtlasNamesWithExtensionResolve() throws {
    // Xcode's compiled Icons.atlasc lists `good-planks.png`, not `good-planks`.
    let atlas = try SKTextureAtlas(dictionary: ["good-planks.png": tinyImage()])
    #expect(GoodIconLoader.origin(for: .planks, atlas: atlas) == .atlas(name: GoodIconLoader.atlasName))
}
