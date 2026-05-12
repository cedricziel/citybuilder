import CityCore
import CoreGraphics
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Tests for the `Per-tile art variants` and `Variant assets enforced by
// catalog presence check` and `Renderer picks variants per tile coord`
// requirements added by openspec/changes/add-sprite-art-variants/.
//
// Mapping convention: each `#### Scenario:` in the spec delta maps to one
// `@Test("scenario: <lowercased title>")` here.

// MARK: - Catalog inventory

@Test("scenario: mountain ships four art variants")
func scenarioMountainShipsFourArtVariants() {
    let names = SpriteAtlas.catalogSpriteNames
    let expected = [
        "terrain-mountain",
        "terrain-mountain-v1",
        "terrain-mountain-v2",
        "terrain-mountain-v3"
    ]
    for entry in expected {
        #expect(names.contains(entry), "catalog must declare \(entry)")
    }
}

@Test("scenario: road ships four art variants")
func scenarioRoadShipsFourArtVariants() {
    let names = SpriteAtlas.catalogSpriteNames
    let expected = [
        "building-road",
        "building-road-v1",
        "building-road-v2",
        "building-road-v3"
    ]
    for entry in expected {
        #expect(names.contains(entry), "catalog must declare \(entry)")
    }
}

// MARK: - Variant selector determinism

@Test("scenario: variant selection is a pure function of coord and count")
func scenarioVariantSelectionIsAPureFunctionOfCoordAndCount() {
    // Same input → same output, every time. Two back-to-back calls and
    // a third call far apart in the test run must all agree.
    let coord = TileCoordinate(x: 12, y: 7)
    let first = SpriteAtlas.variantIndex(coord: coord, count: 4)
    let second = SpriteAtlas.variantIndex(coord: coord, count: 4)
    let third = SpriteAtlas.variantIndex(coord: coord, count: 4)
    #expect(first == second)
    #expect(second == third)
    #expect((0 ..< 4).contains(first))
}

@Test("scenario: variant selection is in-range")
func scenarioVariantSelectionIsInRange() {
    // Probe a small grid with several variant counts. Every returned
    // index MUST satisfy 0 <= idx < count for the call's count.
    for count in [2, 3, 4, 7] {
        for x in -3 ... 3 {
            for y in -3 ... 3 {
                let coord = TileCoordinate(x: x, y: y)
                let idx = SpriteAtlas.variantIndex(coord: coord, count: count)
                #expect(idx >= 0)
                #expect(idx < count)
            }
        }
    }
}

@Test("scenario: variant zero when count is one")
func scenarioVariantZeroWhenCountIsOne() {
    // Kinds not listed in the variant tables resolve count = 1; the
    // selector MUST return 0 unconditionally so the canonical sprite
    // is picked.
    for coord in [
        TileCoordinate(x: 0, y: 0),
        TileCoordinate(x: 100, y: -50),
        TileCoordinate(x: -1, y: 1),
        TileCoordinate(x: 7, y: 3)
    ] {
        #expect(SpriteAtlas.variantIndex(coord: coord, count: 1) == 0)
    }
}

@Test("scenario: distinct coords map across the full variant range")
func scenarioDistinctCoordsMapAcrossTheFullVariantRange() {
    // Across a 16×16 grid the selector MUST hit every index 0..<4 at
    // least once. This guards against a hash that degenerates to a
    // constant (or to a single parity class) without being a strict
    // uniformity claim — the spec only requires "appears at least once".
    var seen: Set<Int> = []
    for x in 0 ..< 16 {
        for y in 0 ..< 16 {
            seen.insert(SpriteAtlas.variantIndex(coord: TileCoordinate(x: x, y: y), count: 4))
        }
    }
    #expect(seen == [0, 1, 2, 3], "expected every index 0..<4 to appear; saw \(seen.sorted())")
}

// MARK: - Catalog presence enforcement

@Test("scenario: missing variant png fails the debug catalog check")
func scenarioMissingVariantPngFailsTheDebugCatalogCheck() {
    // A synthesised variant name that the catalog never declares serves
    // as the fixture for "this variant PNG is missing". The presence
    // check returns it in the missing-list, which is the input
    // assertCatalogComplete fires its precondition on.
    SpriteAtlas.resetForTesting()
    let absent = "terrain-mountain-v99"
    let missing = SpriteAtlas.missingSprites(in: [absent])
    #expect(missing.contains(absent))
}

@Test("scenario: complete variant inventory passes the debug catalog check")
func scenarioCompleteVariantInventoryPassesTheDebugCatalogCheck() {
    // The catalog enumerator MUST list every variant declared in the
    // SpriteAtlas tables. Whether each PNG resolves at runtime is
    // covered by the per-process assertCatalogComplete check that runs
    // at app launch; here we pin the enumeration contract that gives
    // that check something to verify.
    let names = SpriteAtlas.catalogSpriteNames
    for (kind, count) in SpriteAtlas.terrainVariantCounts {
        for variant in 0 ..< count {
            let expected = SpriteAtlas.variantAssetName(stem: "terrain-\(kind.rawValue)", variant: variant)
            #expect(names.contains(expected), "catalog must declare \(expected)")
        }
    }
    for (kind, count) in SpriteAtlas.buildingVariantCounts {
        for variant in 0 ..< count {
            let expected = SpriteAtlas.variantAssetName(stem: "building-\(kind.rawValue)", variant: variant)
            #expect(names.contains(expected), "catalog must declare \(expected)")
        }
    }
}

// MARK: - Renderer texture lookup uses the variant selector

@Test("scenario: placed mountain tile picks its variant from its coord")
func scenarioPlacedMountainTilePicksItsVariantFromItsCoord() {
    // The variant-aware lookup MUST be functionally equivalent to:
    //   textureOrPlaceholder(named: variantAssetName(stem, variantIndex(coord, count)))
    // Identity (`===`) holds because the named-texture cache returns
    // the same SKTexture instance for a given name; if the asset is
    // missing both sides resolve to the shared placeholderTexture.
    SpriteAtlas.resetForTesting()
    let count = SpriteAtlas.terrainVariantCounts[.mountain] ?? 1
    for coord in [
        TileCoordinate(x: 0, y: 0),
        TileCoordinate(x: 4, y: 11),
        TileCoordinate(x: 7, y: 3),
        TileCoordinate(x: 13, y: 8)
    ] {
        let variant = SpriteAtlas.variantIndex(coord: coord, count: count)
        let expected = SpriteAtlas.textureOrPlaceholder(
            named: SpriteAtlas.variantAssetName(stem: "terrain-mountain", variant: variant)
        )
        let actual = SpriteAtlas.terrainTextureOrPlaceholder(for: .mountain, coord: coord)
        #expect(actual === expected, "mountain at \(coord) must resolve via variant index \(variant)")
    }
}

@Test("scenario: placed road tile picks its variant from its coord")
func scenarioPlacedRoadTilePicksItsVariantFromItsCoord() {
    SpriteAtlas.resetForTesting()
    let count = SpriteAtlas.buildingVariantCounts[.road] ?? 1
    for coord in [
        TileCoordinate(x: 1, y: 1),
        TileCoordinate(x: 9, y: 4),
        TileCoordinate(x: 5, y: 12),
        TileCoordinate(x: 0, y: 7)
    ] {
        let variant = SpriteAtlas.variantIndex(coord: coord, count: count)
        let expected = SpriteAtlas.textureOrPlaceholder(
            named: SpriteAtlas.variantAssetName(stem: "building-road", variant: variant)
        )
        let actual = SpriteAtlas.buildingTextureOrPlaceholder(for: .road, coord: coord)
        #expect(actual === expected, "road at \(coord) must resolve via variant index \(variant)")
    }
}

// MARK: - Ghost preview wiring

@MainActor
private final class FixtureSnapshotDataSource: IsoWorldDataSource {
    var snapshot: WorldSnapshot
    init(snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

@Test("scenario: ghost preview matches placement variant")
@MainActor
func scenarioGhostPreviewMatchesPlacementVariant() {
    // Drive IsoWorldScene through one update with a road ghost at a
    // known coord; the resulting ghost node's texture MUST be identical
    // (cache identity via `===`) to the texture the placed road tile
    // would use at that coord. The ghost is the only child with
    // zPosition 1000, so it is unambiguous to locate.
    SpriteAtlas.resetForTesting()
    let world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    var camWorld = world
    camWorld.camera = Camera(centerX: 2, centerY: 2, zoom: 1.0)
    let dataSource = FixtureSnapshotDataSource(snapshot: camWorld.snapshot())

    let scene = IsoWorldScene(size: CGSize(width: 800, height: 600))
    scene.dataSource = dataSource
    let ghostCoord = TileCoordinate(x: 1, y: 2)
    scene.ghostProvider = {
        IsoWorldScene.GhostState(kind: .road, tile: ghostCoord, valid: true)
    }
    scene.update(0)

    let placementTexture = SpriteAtlas.buildingTextureOrPlaceholder(for: .road, coord: ghostCoord)
    let ghost = scene.children
        .compactMap { $0 as? SKSpriteNode }
        .first { $0.zPosition == 1000 }

    guard let ghost else {
        Issue.record("expected ghost preview node with zPosition 1000 after update")
        return
    }
    #expect(
        ghost.texture === placementTexture,
        "ghost texture at \(ghostCoord) must match the placement texture for the same coord"
    )
}
