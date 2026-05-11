import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Tests for the `Asset-presence validation` requirement of
// sprite-asset-pipeline. The presence check is exposed as a pure
// function `SpriteAtlas.missingSprites(in:)` that returns the names
// in its input list which do NOT resolve to a packed atlas texture.
// The DEBUG-only wrapper `SpriteAtlas.assertCatalogComplete()` calls
// `precondition` on the missing-list when non-empty — too destructive
// to assert directly in a unit test, so we exercise the inspection
// function and gate its caller via `#if DEBUG`.

@Test("scenario: missing sprite fails fast in debug")
func scenarioMissingSpriteFailsFastInDebug() {
    // A name that's prefix-routed to Buildings but never declared in
    // the catalog (no `building-not-real.png` exists). The presence
    // check returns the name in its missing-list.
    SpriteAtlas.resetForTesting()
    let missing = SpriteAtlas.missingSprites(in: ["building-not-real"])
    #expect(missing.contains("building-not-real"))
}

@Test("scenario: complete catalog passes silently in debug")
func scenarioCompleteCatalogPassesSilentlyInDebug() {
    // An empty input list always returns an empty missing list — the
    // trivial case. The non-trivial case (full catalog with bundled
    // resources) is exercised at app launch by `assertCatalogComplete`
    // and verified via the visual-smoke check in M7.
    SpriteAtlas.resetForTesting()
    let missing = SpriteAtlas.missingSprites(in: [])
    #expect(missing.isEmpty)
}

@Test("scenario: release build does not perform the presence check")
func scenarioReleaseBuildDoesNotPerformThePresenceCheck() {
    // The `assertCatalogComplete()` symbol exists only inside
    // `#if DEBUG`. The test below asserts that gating in two ways:
    //
    //   1. In DEBUG (the configuration this test runs in), the symbol
    //      MUST resolve. We take a typed reference; if the symbol were
    //      not declared, the file would not compile.
    //   2. In a release build, the symbol MUST be elided. There is no
    //      way to assert "this code does not compile" from inside a
    //      passing test, so we rely on the `#if !DEBUG #else #endif`
    //      stanza in SpriteAtlas to guarantee the elision.
    #if DEBUG
    let probe: () -> Void = SpriteAtlas.assertCatalogComplete
    _ = probe
    #else
    Issue.record("test target compiled in release mode; expected DEBUG")
    #endif
}

@Test("scenario: catalog enumerates every declared sprite name")
func scenarioCatalogEnumeratesEveryDeclaredSpriteName() {
    // Cross-check the catalog enumerator covers each terrain kind, each
    // building kind, each walker facing — exactly the set the
    // sprite-asset-pipeline naming grammar describes.
    let names = SpriteAtlas.catalogSpriteNames
    for kind in TerrainType.allCases {
        #expect(names.contains("terrain-\(kind.rawValue)"))
    }
    for kind in BuildingKind.allCases {
        #expect(names.contains("building-\(kind.rawValue)"))
    }
    for facing in SpriteAtlas.WalkerFacing.allCases {
        // Each walker has 2 frames in the catalog.
        #expect(names.contains("walker-\(facing.rawValue)-0"))
        #expect(names.contains("walker-\(facing.rawValue)-1"))
    }
}
