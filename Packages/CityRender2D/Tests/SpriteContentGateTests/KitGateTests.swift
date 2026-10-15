#if canImport(ImageIO)
import Foundation
import Testing
@testable import SpriteContentGate

/// Gate rules from `replace-generative-sprites-with-isokit` (sprite-asset-pipeline).
@Suite("Content gate: art-kit rules")
struct KitGateTests {
    private func writeBrief(_ root: URL, id: String, source: String, recipe: String = "") throws {
        let url = root.appendingPathComponent("Sprites.style/catalog/\(id).md")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "---\nsource = \"\(source)\"\n---\n## Function\n\n## Recipe\n\n\(recipe)\n".write(to: url, atomically: true, encoding: .utf8)
    }

    private func grounded(width: Int = 64, height: Int = 32, scale: Int = 1) -> RGBAImage {
        image(width: width * scale, height: height * scale) { x, y in
            (20 * scale ..< 44 * scale).contains(x) && (4 * scale ..< height * scale).contains(y) ? (y < 14 * scale ? roof : wall) : nil
        }
    }

    @Test("scenario: Content gate accepts sails sweeping past the wall")
    func acceptsSailsSweepingPastTheWall() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "building-sawmill", source: "procedural", recipe: "- Moving part: sails, 4 frames, sweeps right")
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(houseSprite(), to: atlas.appendingPathComponent("building-sawmill.png"))
        let withSails = image { x, y in
            if (44 ..< 53).contains(x), (6 ..< 12).contains(y) { return wall } // a blade 9 px past the wall
            guard (20 ..< 44).contains(x), (4 ..< 32).contains(y) else { return nil }
            return y < 14 ? roof : wall
        }
        try writePNG(withSails, to: atlas.appendingPathComponent("building-sawmill-operational-0.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.3)

        #expect(!failures.contains { $0.reason == .frameMisaligned })
    }

    @Test("a frame shifted on an edge no part sweeps is still misaligned")
    func unsweptEdgeStillChecked() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "building-sawmill", source: "procedural", recipe: "- Moving part: sails, 4 frames, sweeps right")
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(houseSprite(), to: atlas.appendingPathComponent("building-sawmill.png"))
        try writePNG(houseSprite(shiftX: -6), to: atlas.appendingPathComponent("building-sawmill-operational-0.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.3)

        #expect(failures.contains(.init(file: "building-sawmill-operational-0.png", reason: .frameMisaligned)))
    }

    @Test("scenario: Rendered buildings without an outline pass")
    func renderedBuildingsWithoutOutlinePass() throws {
        let root = temporaryResources()
        try writePNG(grounded(), to: root.appendingPathComponent("Buildings.atlas/building-house.png"))

        #expect(try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2).isEmpty)
    }

    @Test("scenario: Content gate rejects a floating rendered building")
    func rejectsFloatingRenderedBuilding() throws {
        let root = temporaryResources()
        let floating = image { x, y in (20 ..< 44).contains(x) && (4 ..< 22).contains(y) ? wall : nil }
        try writePNG(floating, to: root.appendingPathComponent("Buildings.atlas/building-house.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures == [.init(file: "building-house.png", reason: .notGrounded)])
    }

    @Test("scenario: Content gate rejects an under-filled tile")
    func rejectsUnderFilledTile() throws {
        let root = temporaryResources()
        let chipped = image { x, y in
            guard insideDiamond(x, y) else { return nil }
            return x == 32 && y == 1 ? nil : water // one transparent pixel on the top edge
        }
        try writePNG(chipped, to: root.appendingPathComponent("Terrain.atlas/terrain-grass-beach-t3.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.2)

        #expect(failures.contains(.init(file: "terrain-grass-beach-t3.png", reason: .terrainCoverageBelowThreshold)))
    }

    @Test("a tile bleeding one point past the diamond passes, two points fails")
    func bleedLimit() throws {
        let root = temporaryResources()
        let bleed = { (points: Double) in
            image { x, y in
                abs(Double(x) + 0.5 - 32) / (32 + 2 * points) + abs(Double(y) + 0.5 - 16) / (16 + points) <= 1 ? water : nil
            }
        }
        try writePNG(bleed(1), to: root.appendingPathComponent("Terrain.atlas/terrain-water.png"))
        try writePNG(bleed(2.5), to: root.appendingPathComponent("Terrain.atlas/terrain-beach.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.9)

        #expect(failures == [.init(file: "terrain-beach.png", reason: .terrainOutsideDiamond)])
    }

    @Test("scenario: Every atlas PNG has an @2x twin")
    func everyMigratedPNGHasATwin() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "building-house", source: "isokit")
        try writeBrief(root, id: "building-bakery", source: "procedural")
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(grounded(), to: atlas.appendingPathComponent("building-house.png"))
        try writePNG(grounded(), to: atlas.appendingPathComponent("building-bakery.png")) // legacy: no twin needed

        var failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.3)
        #expect(failures == [.init(file: "building-house.png", reason: .scaleTwinMismatch)])

        try writePNG(grounded(scale: 2), to: atlas.appendingPathComponent("building-house@2x.png"))
        failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.3)
        #expect(failures.isEmpty)
    }

    @Test("scenario: Walker frames have the walker size")
    func walkerFramesHaveTheWalkerSize() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "walker", source: "isokit")
        let atlas = root.appendingPathComponent("Units.atlas")
        let figure = { (scale: Int) in image(width: 10 * scale, height: 16 * scale) { x, _ in x % 2 == 0 ? wall : roof } }
        for facing in ["ne", "nw", "se", "sw"] {
            for frame in 0 ..< 4 {
                try writePNG(figure(1), to: atlas.appendingPathComponent("walker-\(facing)-\(frame).png"))
                try writePNG(figure(2), to: atlas.appendingPathComponent("walker-\(facing)-\(frame)@2x.png"))
            }
        }
        #expect(try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.9).isEmpty)

        try writePNG(image(width: 8, height: 12) { _, _ in wall }, to: atlas.appendingPathComponent("walker-se-0.png"))
        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.9)
        #expect(failures.contains(.init(file: "walker-se-0.png", reason: .walkerSize)))
    }

    @Test("scenario: Every facing has four gait frames")
    func everyFacingHasFourGaitFrames() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "walker", source: "isokit")
        let atlas = root.appendingPathComponent("Units.atlas")
        for facing in ["ne", "nw", "se", "sw"] {
            for frame in 0 ..< (facing == "nw" ? 3 : 4) {
                try writePNG(
                    image(width: 10, height: 16) { _, _ in wall },
                    to: atlas.appendingPathComponent("walker-\(facing)-\(frame).png")
                )
                try writePNG(
                    image(width: 20, height: 32) { _, _ in wall },
                    to: atlas.appendingPathComponent("walker-\(facing)-\(frame)@2x.png")
                )
            }
        }

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.9)

        #expect(failures == [.init(file: "walker-nw-3.png", reason: .walkerFramesMissing)])
    }

    @Test("scenario: Verification fails on a content defect")
    func verificationFailsOnContentDefect() throws {
        let root = temporaryResources()
        try writePNG(waterFrame(glintPhase: 0), to: root.appendingPathComponent("Terrain.atlas/terrain-water.png"))
        try writePNG(image { _, _ in nil }, to: root.appendingPathComponent("Terrain.atlas/terrain-water-2.png"))

        let report = try SpriteContentGate.run(arguments: [root.path, "--max-distance", "0.2"])

        #expect(report.exitCode != 0)
        #expect(report.output.contains("terrain-water-2.png frame_empty"))
    }

    @Test("@2x frames compare against their @2x base")
    func twoXFramesUseTwoXBase() {
        #expect(SpriteContentGate.coherenceBase(for: "building-sawmill-operational-1@2x.png") == "building-sawmill@2x.png")
        #expect(SpriteFile("terrain-grass-beach-t3@2x.png") == SpriteFile("terrain-grass-beach-t3@2x.png"))
        #expect(SpriteFile("terrain-grass-beach-t3@2x.png").stem == "terrain-grass-beach-t3")
        #expect(GateCatalog(entries: [.init(id: "building-house", source: "isokit")])
            .entry(forSprite: "building-house-tier2@2x.png")?.id == "building-house")
    }
}
#endif
