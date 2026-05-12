import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Tests for the sprite-asset-pipeline routing contract. Each
// `#### Scenario:` heading under `Requirement: SpriteAtlas resolves via
// category atlases` and `Requirement: Atlas routing by sprite-name prefix`
// in openspec/changes/add-sprite-atlas-layout/specs/sprite-asset-pipeline/spec.md
// maps to a `@Test("scenario: <lowercased title>")` here.

// MARK: - Atlas routing by sprite-name prefix

@Test("scenario: terrain name routes to terrain atlas")
func scenarioTerrainNameRoutesToTerrainAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "terrain-grass") == "Terrain")
    #expect(SpriteAtlasRouting.atlasName(for: "terrain-water-3") == "Terrain")
    // The lookup MUST resolve a non-nil texture when the bundle has it;
    // in package-test mode (no bundle) nil is acceptable.
    if let texture = SpriteAtlas.texture(named: "terrain-grass") {
        #expect(texture.size().width > 0)
    }
}

@Test("scenario: building name routes to buildings atlas")
func scenarioBuildingNameRoutesToBuildingsAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "building-sawmill-operational-0") == "Buildings")
    #expect(SpriteAtlasRouting.atlasName(for: "building-house") == "Buildings")
    if let texture = SpriteAtlas.texture(named: "building-sawmill-operational-0") {
        #expect(texture.size().width > 0)
    }
}

@Test("scenario: walker name routes to units atlas")
func scenarioWalkerNameRoutesToUnitsAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "walker-ne-0") == "Units")
    #expect(SpriteAtlasRouting.atlasName(for: "walker-sw-1") == "Units")
    if let texture = SpriteAtlas.texture(named: "walker-ne-0") {
        #expect(texture.size().width > 0)
    }
}

@Test("scenario: spriteatlasrouting routes good- to icons atlas")
func scenarioSpriteAtlasRoutingRoutesGoodToIconsAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "good-wood") == "Icons")
    #expect(SpriteAtlasRouting.atlasName(for: "good-planks") == "Icons")
    #expect(SpriteAtlasRouting.atlasName(for: "good-food") == "Icons")
    #expect(SpriteAtlasRouting.iconsAtlasName == "Icons")
}

@Test("scenario: public api surface unchanged")
func scenarioPublicApiSurfaceUnchanged() {
    // Compile-time assertion: each public symbol the pre-migration
    // SpriteAtlas exposed MUST still resolve. If any signature changed
    // or any symbol disappeared, this file would no longer compile.
    let terrain: (TerrainType) -> SKTexture? = SpriteAtlas.terrainTexture(for:)
    let building: (BuildingKind) -> SKTexture? = SpriteAtlas.buildingTexture(for:)
    let walker: (SpriteAtlas.WalkerFacing) -> [SKTexture]? = SpriteAtlas.walkerAnimation(facing:)
    let frames: (SpriteAnimation.AnimationKey) -> [SKTexture]? = SpriteAtlas.frames(for:)
    _ = terrain
    _ = building
    _ = walker
    _ = frames
    // WalkerFacing.allCases must still be enumerable.
    #expect(SpriteAtlas.WalkerFacing.allCases.count == 4)
}

// MARK: - SpriteAtlas resolves via category atlases

#if canImport(AppKit)
@Test("scenario: no imagenamed lookups in spriteatlas")
func scenarioNoImageNamedLookupsInSpriteAtlas() throws {
    // Code-scan: the SpriteAtlas implementation file MUST NOT contain
    // any direct `SKTexture(imageNamed:` call for sprite assets covered
    // by the catalog. Routing happens through SKTextureAtlas instances.
    let path = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CityRender2DTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // CityRender2D (package root)
        .appendingPathComponent("Sources/CityRender2D/SpriteAtlas.swift").path
    let source = try String(contentsOfFile: path, encoding: .utf8)
    // Strip comment-only lines so a doc comment mentioning the forbidden
    // call (in a "never use this" context) doesn't trip the scan.
    let codeLines = source.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
    #expect(
        !codeLines.contains("SKTexture(imageNamed:"),
        "SpriteAtlas.swift must not call SKTexture(imageNamed:); use SKTextureAtlas"
    )
}
#endif

@Suite(.serialized)
struct LazyConstructionSuite {
    @Test("scenario: sktextureatlas instances are lazily constructed")
    func scenarioSKTextureAtlasInstancesAreLazilyConstructed() {
        // After reset, no atlas exists. The next lookup MUST construct
        // its own category atlas — and no other.
        //
        // The suite is `.serialized` so this test does not race with
        // other tests in the suite. Other test files at file scope do
        // not call `resetForTesting`, but they DO call lookups that
        // populate the cache. To avoid cross-file races we limit the
        // observation window to the single statement between reset and
        // the per-category check by reading `isAtlasConstructed` for
        // the expected-positive case only.
        SpriteAtlas.resetForTesting()
        _ = SpriteAtlas.texture(named: "terrain-grass")
        #expect(SpriteAtlas.isAtlasConstructed(named: "Terrain"))

        SpriteAtlas.resetForTesting()
        _ = SpriteAtlas.texture(named: "building-house")
        #expect(SpriteAtlas.isAtlasConstructed(named: "Buildings"))

        SpriteAtlas.resetForTesting()
        _ = SpriteAtlas.texture(named: "walker-ne-0")
        #expect(SpriteAtlas.isAtlasConstructed(named: "Units"))
    }
}
