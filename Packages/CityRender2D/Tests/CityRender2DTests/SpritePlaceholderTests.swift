import CoreGraphics
import Foundation
import SpriteKit
import Synchronization
import Testing
@testable import CityRender2D

// Tests for the `Missing-sprite fallback in release` requirement of
// rendering-2_5d (added by add-sprite-atlas-layout). The placeholder
// path is exposed as `SpriteAtlas.textureOrPlaceholder(named:)`,
// which never returns nil: a known sprite resolves to its packed
// texture, an unknown sprite resolves to a 32×32 magenta placeholder
// and the missing name is logged exactly once per process lifetime.

/// Records what a test's own miss log reports, so tests running in parallel never share one.
private final class MissRecorder: Sendable {
    private let names = Mutex<[String]>([])

    func record(_ name: String) {
        names.withLock { $0.append(name) }
    }

    var logged: [String] {
        names.withLock(\.self)
    }
}

@Test("scenario: placeholder drawn for missing sprite")
func scenarioPlaceholderDrawnForMissingSprite() {
    let tex = SpriteAtlas.textureOrPlaceholder(named: "building-truly-not-real", log: MissLog(sink: MissRecorder().record))
    // Placeholder is 32×32 magenta. Verify the geometry the spec
    // requires; the magenta color is a visual contract enforced
    // by the implementation rather than asserted here.
    let size = tex.size()
    #expect(size.width == 32)
    #expect(size.height == 32)
}

@Test("scenario: missing sprite logged once")
func scenarioMissingSpriteLoggedOnce() {
    let recorder = MissRecorder()
    let log = MissLog(sink: recorder.record)
    let name = "walker-truly-not-real"

    _ = SpriteAtlas.textureOrPlaceholder(named: name, log: log)
    _ = SpriteAtlas.textureOrPlaceholder(named: name, log: log)
    _ = SpriteAtlas.textureOrPlaceholder(named: name, log: log)

    #expect(recorder.logged == [name], "expected exactly one log entry for \(name)")
}

@Test("scenario: missing sprite distinct names log independently")
func scenarioMissingSpriteDistinctNamesLogIndependently() {
    let recorder = MissRecorder()
    let log = MissLog(sink: recorder.record)

    _ = SpriteAtlas.textureOrPlaceholder(named: "terrain-truly-not-real-a", log: log)
    _ = SpriteAtlas.textureOrPlaceholder(named: "terrain-truly-not-real-b", log: log)
    _ = SpriteAtlas.textureOrPlaceholder(named: "terrain-truly-not-real-a", log: log)

    #expect(recorder.logged == [
        "terrain-truly-not-real-a",
        "terrain-truly-not-real-b"
    ])
}
