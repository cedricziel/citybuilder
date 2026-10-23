#if canImport(ImageIO)
import Foundation
import ImageIO
import SpriteContentGate
import Testing
import UniformTypeIdentifiers

@Suite("Sprite content gate")
struct SpriteContentGateTests {
    @Test("scenario: content gate rejects an under-filled terrain sprite")
    func rejectsUnderFilledTerrain() throws {
        let root = temporaryResources()
        let sparse = image { x, y in
            insideDiamond(x, y) && (24 ..< 40).contains(x) ? water : nil
        }
        try writePNG(sparse, to: root.appendingPathComponent("Terrain.atlas/terrain-grass.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures.contains(.init(file: "terrain-grass.png", reason: .terrainCoverageBelowThreshold)))
    }

    @Test("scenario: content gate rejects a fully transparent frame")
    func rejectsEmptyFrame() throws {
        let root = temporaryResources()
        try writePNG(waterFrame(glintPhase: 0), to: root.appendingPathComponent("Terrain.atlas/terrain-water.png"))
        try writePNG(image { _, _ in nil }, to: root.appendingPathComponent("Terrain.atlas/terrain-water-2.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures.contains(.init(file: "terrain-water-2.png", reason: .frameEmpty)))
    }

    @Test("scenario: content gate rejects a frame that depicts a different object")
    func rejectsIncoherentFrame() throws {
        let root = temporaryResources()
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(waterFrame(glintPhase: 0), to: atlas.appendingPathComponent("terrain-water.png"))
        try writePNG(houseSprite(), to: atlas.appendingPathComponent("terrain-water-1.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures.contains(.init(file: "terrain-water-1.png", reason: .frameIncoherent)))
    }

    @Test("scenario: content gate accepts coherent water frames")
    func acceptsCoherentFrames() throws {
        let root = temporaryResources()
        let atlas = root.appendingPathComponent("Terrain.atlas")
        try writePNG(waterFrame(glintPhase: 0), to: atlas.appendingPathComponent("terrain-water.png"))
        for phase in 0 ..< 4 {
            try writePNG(
                waterFrame(glintPhase: phase * 3),
                to: atlas.appendingPathComponent("terrain-water-\(phase).png")
            )
        }

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures.isEmpty)
    }

    @Test("construction stages are not compared against the finished sprite")
    func constructionStagesSkipCoherence() throws {
        let root = temporaryResources()
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(houseSprite(), to: atlas.appendingPathComponent("building-house.png"))
        try writePNG(waterFrame(glintPhase: 0), to: atlas.appendingPathComponent("building-house-constructing-0.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures.isEmpty)
    }

    @Test("operational frames compare against the building's base sprite")
    func operationalFramesUseKindBase() throws {
        let root = temporaryResources()
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(houseSprite(), to: atlas.appendingPathComponent("building-sawmill.png"))
        try writePNG(waterFrame(glintPhase: 0), to: atlas.appendingPathComponent("building-sawmill-operational-0.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures.contains(.init(file: "building-sawmill-operational-0.png", reason: .frameIncoherent)))
    }

    @Test("scenario: content gate rejects a shifted operational frame")
    func rejectsShiftedOperationalFrame() throws {
        let root = temporaryResources()
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(houseSprite(), to: atlas.appendingPathComponent("building-sawmill.png"))
        try writePNG(houseSprite(shiftX: -6), to: atlas.appendingPathComponent("building-sawmill-operational-0.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures == [.init(file: "building-sawmill-operational-0.png", reason: .frameMisaligned)])
    }

    @Test("scenario: content gate accepts smoke above the roof")
    func acceptsSmokeAboveRoof() throws {
        let root = temporaryResources()
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(houseSprite(), to: atlas.appendingPathComponent("building-sawmill.png"))
        try writePNG(houseSprite(smoke: true), to: atlas.appendingPathComponent("building-sawmill-operational-0.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures.isEmpty)
    }

    @Test("scenario: content gate rejects a floating building")
    func rejectsFloatingBuilding() throws {
        let root = temporaryResources()
        let floating = image { x, y in
            guard (20 ..< 44).contains(x), (4 ..< 22).contains(y) else { return nil }
            return y == 21 ? outline : wall
        }
        try writePNG(floating, to: root.appendingPathComponent("Buildings.atlas/building-port-e.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures == [.init(file: "building-port-e.png", reason: .notGrounded)])
    }

    @Test("roads and frames are exempt from building base checks")
    func roadsAndFramesExempt() throws {
        let root = temporaryResources()
        let floating = image { x, y in (20 ..< 44).contains(x) && (4 ..< 20).contains(y) ? wall : nil }
        try writePNG(floating, to: root.appendingPathComponent("Buildings.atlas/building-road.png"))
        try writePNG(floating, to: root.appendingPathComponent("Buildings.atlas/building-house-constructing-0.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures.isEmpty)
    }

    @Test("scenario: verification fails on a content defect even when bytes reproduce")
    func executableExitsNonZeroOnDefect() throws {
        let root = temporaryResources()
        try writePNG(waterFrame(glintPhase: 0), to: root.appendingPathComponent("Terrain.atlas/terrain-water.png"))
        try writePNG(image { _, _ in nil }, to: root.appendingPathComponent("Terrain.atlas/terrain-water-2.png"))

        let report = try SpriteContentGate.run(arguments: [root.path, "--max-distance", "0.2"])

        #expect(report.exitCode != 0)
        #expect(report.output.contains("terrain-water-2.png frame_empty"))
    }

    /// The threshold is the gate's own; it no longer reads a pipeline config file.
    @Test("the gate runs without a pipeline config, at its own coherence threshold")
    func gateRunsWithoutConfig() throws {
        let root = temporaryResources()
        try writePNG(waterFrame(glintPhase: 0), to: root.appendingPathComponent("Kit.atlas/terrain-water.png"))

        let report = try SpriteContentGate.run(arguments: [root.path])

        #expect(report.exitCode == 0, "\(report.output)")
        #expect(SpriteContentGate.coherenceMaxDistance == 0.3)
    }
}
#endif
