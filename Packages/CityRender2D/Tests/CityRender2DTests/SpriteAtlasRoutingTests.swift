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

@Test("terrain names route to the kit atlas")
func terrainNamesRouteToTheKitAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "terrain-grass") == "Kit")
    #expect(SpriteAtlasRouting.atlasName(for: "terrain-water-3") == "Kit")
    #expect(SpriteAtlasRouting.atlasName(for: "terrain-grass-beach-t3-winter") == "Kit")
    // The lookup MUST resolve a non-nil texture when the bundle has it;
    // in package-test mode (no bundle) nil is acceptable.
    if let texture = SpriteAtlas.texture(named: "terrain-grass") {
        #expect(texture.size().width > 0)
    }
}

@Test(
    "scenario: building name routes to buildings atlas",
    .enabled(if: legacyBuildingStem != nil, "every building family is on the art kit; no legacy building is left")
)
func scenarioBuildingNameRoutesToBuildingsAtlas() throws {
    let stem = try #require(legacyBuildingStem)
    #expect(SpriteAtlasRouting.atlasName(for: stem) == "Buildings")
    #expect(SpriteAtlasRouting.atlasName(for: "\(stem)-constructing-0") == "Buildings")
}

/// The building sprites committed in the legacy Buildings.atlas, by name; empty once it is gone.
let legacyBuildingSprites: [String] = {
    let atlas = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Buildings.atlas")
    let files = (try? FileManager.default.contentsOfDirectory(atPath: atlas.path)) ?? []
    return files.filter { $0.hasPrefix("building-") && $0.hasSuffix(".png") && !$0.hasSuffix("@2x.png") }
        .map { String($0.dropLast(".png".count)) }.sorted()
}()

/// A building sprite still drawn as legacy pixel art: the first committed Buildings.atlas file whose
/// stem is outside the art kit (an age or culture look, a directional port). Found at runtime, so a
/// family migration never breaks the tests that need one; nil once no legacy building is left.
let legacyBuildingStem: String? = legacyBuildingSprites.first {
    !TextureFiltering.kitRenderedStems.contains(TextureFiltering.stem(of: $0))
}

/// SpriteKit filters a whole atlas page with one mode (the last one set wins), so the linearly
/// filtered art-kit renders cannot share a page with nearest-filtered pixel art (design D7).
@Test("scenario: Linear and nearest textures never share an atlas")
func kitRendersRouteToTheKitAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "building-house") == "Kit")
    #expect(SpriteAtlasRouting.atlasName(for: "building-house-tier2") == "Kit")
    #expect(SpriteAtlasRouting.atlasName(for: "building-town-center-operational-1") == "Kit")
    #expect(SpriteAtlasRouting.allAtlasNames.contains("Kit"))
    for name in ["building-house", "building-sawmill", "good-wood", "terrain-grass", "walker-ne-0"] {
        let linear = TextureFiltering.mode(for: name) == .linear
        #expect(linear == (SpriteAtlasRouting.atlasName(for: name) == "Kit"), "\(name)")
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
    func scenarioSKTextureAtlasInstancesAreLazilyConstructed() throws {
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
        _ = SpriteAtlas.texture(named: "walker-ne-0")
        #expect(SpriteAtlas.isAtlasConstructed(named: "Units"))

        SpriteAtlas.resetForTesting()
        _ = SpriteAtlas.texture(named: "terrain-grass")
        #expect(SpriteAtlas.isAtlasConstructed(named: "Kit"))

        if !legacyBuildingSprites.isEmpty {
            SpriteAtlas.resetForTesting()
            _ = try SpriteAtlas.texture(named: #require(legacyBuildingStem, "Buildings.atlas holds only kit-rendered names"))
            #expect(SpriteAtlas.isAtlasConstructed(named: "Buildings"))
        }

        SpriteAtlas.resetForTesting()
        _ = SpriteAtlas.texture(named: "building-house")
        #expect(SpriteAtlas.isAtlasConstructed(named: "Kit"))

        SpriteAtlas.resetForTesting()
        _ = SpriteAtlas.texture(named: "walker-ne-0")
        #expect(SpriteAtlas.isAtlasConstructed(named: "Units"))
    }
}

@Test("scenario: waiting badge routes to the buildings atlas")
func scenarioWaitingBadgeRoutesToTheBuildingsAtlas() {
    #expect(SpriteAtlasRouting.atlasName(for: "overlay-waiting-materials") == SpriteAtlasRouting.buildingsAtlasName)
}
