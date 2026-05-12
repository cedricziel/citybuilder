import CoreGraphics
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Tests for the `Missing-sprite fallback in release` requirement of
// rendering-2_5d (added by add-sprite-atlas-layout). The placeholder
// path is exposed as `SpriteAtlas.textureOrPlaceholder(named:)`,
// which never returns nil: a known sprite resolves to its packed
// texture, an unknown sprite resolves to a 32×32 magenta placeholder
// and the missing name is logged exactly once per process lifetime.

@Suite(.serialized)
struct PlaceholderSuite {
    @Test("scenario: placeholder drawn for missing sprite")
    func scenarioPlaceholderDrawnForMissingSprite() {
        SpriteAtlas.resetMissLogForTesting()
        let tex = SpriteAtlas.textureOrPlaceholder(named: "building-truly-not-real")
        // Placeholder is 32×32 magenta. Verify the geometry the spec
        // requires; the magenta color is a visual contract enforced
        // by the implementation rather than asserted here.
        let size = tex.size()
        #expect(size.width == 32)
        #expect(size.height == 32)
    }

    @Test("scenario: missing sprite logged once")
    func scenarioMissingSpriteLoggedOnce() {
        SpriteAtlas.resetMissLogForTesting()
        let name = "walker-truly-not-real"
        // Filter to this test's name so concurrent tests in other suites
        // that happen to also call `textureOrPlaceholder` for unrelated
        // missing sprites can't pollute the observed list.
        var observed: [String] = []
        SpriteAtlas.missLogHook = { hooked in
            if hooked == name { observed.append(hooked) }
        }
        defer { SpriteAtlas.missLogHook = nil }

        _ = SpriteAtlas.textureOrPlaceholder(named: name)
        _ = SpriteAtlas.textureOrPlaceholder(named: name)
        _ = SpriteAtlas.textureOrPlaceholder(named: name)

        #expect(observed == [name], "expected exactly one log entry for \(name)")
    }

    @Test("scenario: missing sprite distinct names log independently")
    func scenarioMissingSpriteDistinctNamesLogIndependently() {
        SpriteAtlas.resetMissLogForTesting()
        let watched: Set = [
            "terrain-truly-not-real-a",
            "terrain-truly-not-real-b"
        ]
        var observed: [String] = []
        SpriteAtlas.missLogHook = { hooked in
            if watched.contains(hooked) { observed.append(hooked) }
        }
        defer { SpriteAtlas.missLogHook = nil }

        _ = SpriteAtlas.textureOrPlaceholder(named: "terrain-truly-not-real-a")
        _ = SpriteAtlas.textureOrPlaceholder(named: "terrain-truly-not-real-b")
        _ = SpriteAtlas.textureOrPlaceholder(named: "terrain-truly-not-real-a")

        #expect(observed.sorted() == [
            "terrain-truly-not-real-a",
            "terrain-truly-not-real-b"
        ])
    }
}
