#if canImport(ImageIO)
import Foundation
import Testing
@testable import SpriteContentGate

/// Gate rules from `replace-generative-sprites-with-isokit` (sprite-asset-pipeline).
@Suite("Content gate: art-kit rules")
struct KitGateTests {
    private func writeBrief(_ root: URL, id: String, source: String, sprites: String? = nil, recipe: String = "") throws {
        let url = root.appendingPathComponent("Sprites.style/catalog/\(id).md")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "---\nsource = \"\(source)\"\n---\n## Function\n\n## Sprites\n\n\(sprites ?? "- `\(id)`")\n\n## Recipe\n\n\(recipe)\n".write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
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
        try writePNG(chipped, to: root.appendingPathComponent("Kit.atlas/terrain-grass-beach-t3.png")) // terrain rules follow the name

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

    @Test("trees and outcrops stand over their tile, so the diamond rules skip them")
    func terrainObjectsSkipTheDiamondRules() throws {
        let root = temporaryResources()
        let tree = image { x, y in abs(x - 32) < 6 && y < 28 ? water : nil } // tall, narrow, off the diamond
        try writePNG(tree, to: root.appendingPathComponent("Kit.atlas/terrain-forest-single.png"))
        let spruce = image { x, y in abs(x - 32) < 6 && y < 28 ? glint : nil }
        try writePNG(spruce, to: root.appendingPathComponent("Kit.atlas/terrain-forest-single-v1.png"))
        try writePNG(tree, to: root.appendingPathComponent("Kit.atlas/terrain-grass.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.9)

        #expect(!failures.contains { $0.file.hasPrefix("terrain-forest-single") })
        #expect(failures.contains { $0.file == "terrain-grass.png" && $0.reason == .terrainCoverageBelowThreshold })
        #expect(SpriteContentGate.isTerrainObject("terrain-mountain-peak-winter-v3@2x.png"))
        #expect(!SpriteContentGate.isTerrainObject("terrain-forest-autumn.png"))
        #expect(!SpriteContentGate.isTerrainObject("terrain-forest-dense-mask.png"))
        #expect(!SpriteContentGate.isTerrainObject("terrain-forest-dense-spring-v1.png"))
        #expect(!SpriteContentGate.isTerrainObject("building-forest-dense.png"))
    }

    @Test("scenario: Every atlas PNG has an @2x twin")
    func everyMigratedPNGHasATwin() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "building-house", source: "isokit")
        try writeBrief(root, id: "building-bakery", source: "procedural")
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(grounded(), to: atlas.appendingPathComponent("building-house.png"))
        try writePNG(grounded(), to: atlas.appendingPathComponent("building-bakery.png")) // legacy, no @2x art yet: fine

        var failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.3)
        #expect(failures == [.init(file: "building-house.png", reason: .scaleTwinMismatch)])

        try writePNG(grounded(scale: 2), to: atlas.appendingPathComponent("building-house@2x.png"))
        try writePNG(grounded(scale: 2), to: atlas.appendingPathComponent("building-bakery@2x.png")) // now the atlas has @2x art
        failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.3)
        #expect(failures.isEmpty)
    }

    /// SpriteKit loads only the @2x pages of such an atlas on retina, so a 1x-only sprite would vanish.
    @Test("in an atlas with @2x art, every sprite needs an @2x twin")
    func everySpriteNeedsATwinOnceTheAtlasHasTwoX() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "building-house", source: "isokit")
        try writeBrief(root, id: "building-bakery", source: "procedural")
        let atlas = root.appendingPathComponent("Buildings.atlas")
        try writePNG(grounded(), to: atlas.appendingPathComponent("building-house.png"))
        try writePNG(grounded(scale: 2), to: atlas.appendingPathComponent("building-house@2x.png"))
        try writePNG(grounded(), to: atlas.appendingPathComponent("building-bakery.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.3)
        #expect(failures == [.init(file: "building-bakery.png", reason: .scaleTwinMismatch)])

        try writePNG(grounded(scale: 2), to: atlas.appendingPathComponent("building-bakery@2x.png"))
        #expect(try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.3).isEmpty)
    }

    @Test("an @2x file without its @1x sprite is an orphan")
    func orphanTwin() throws {
        let root = temporaryResources()
        try writePNG(grounded(scale: 2), to: root.appendingPathComponent("Buildings.atlas/building-ghost@2x.png"))

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.3)

        #expect(failures == [.init(file: "building-ghost@2x.png", reason: .scaleTwinOrphan)])
    }

    @Test("scenario: Walker frames have the walker size")
    func walkerFramesHaveTheWalkerSize() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "walker", source: "isokit")
        let atlas = root.appendingPathComponent("Kit.atlas")
        let figure = { (scale: Int) in image(width: 32 * scale, height: 32 * scale) { x, y in
            (1 ..< 31 * scale).contains(x) && y < 31 * scale ? (x % 2 == 0 ? wall : roof) : nil
        } }
        for facing in ["ne", "nw", "se", "sw"] {
            for frame in 0 ..< 8 {
                try writePNG(figure(1), to: atlas.appendingPathComponent("walker-woman-\(facing)-\(frame).png"))
                try writePNG(figure(2), to: atlas.appendingPathComponent("walker-woman-\(facing)-\(frame)@2x.png"))
            }
        }
        #expect(try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.9).isEmpty)

        try writePNG(image(width: 10, height: 16) { _, _ in wall }, to: atlas.appendingPathComponent("walker-woman-se-0.png"))
        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.9)
        #expect(failures.contains(.init(file: "walker-woman-se-0.png", reason: .walkerSize)))
    }

    @Test("scenario: A clipped walker shadow fails the gate")
    func aClippedWalkerShadowFailsTheGate() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "walker", source: "isokit")
        let atlas = root.appendingPathComponent("Kit.atlas")
        for facing in ["ne", "nw", "se", "sw"] {
            for frame in 0 ..< 8 {
                // Frame se-2's shadow runs into the right edge; the rest stay a pixel inside.
                let clipped = facing == "se" && frame == 2
                for scale in [1, 2] {
                    let edge = 32 * scale - 1
                    let sprite = image(width: 32 * scale, height: 32 * scale) { x, y in
                        (1 ..< (clipped ? edge + 1 : edge)).contains(x) && y < edge ? wall : nil
                    }
                    let file = scale == 1 ? "walker-\(facing)-\(frame).png" : "walker-\(facing)-\(frame)@2x.png"
                    try writePNG(sprite, to: atlas.appendingPathComponent(file))
                }
            }
        }

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.9)

        #expect(failures.count == 2)
        #expect(failures.contains(.init(file: "walker-se-2.png", reason: .walkerClipped)))
        #expect(failures.contains(.init(file: "walker-se-2@2x.png", reason: .walkerClipped)))
    }

    @Test("scenario: A missing gait frame fails the gate")
    func aMissingGaitFrameFailsTheGate() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "carrier", source: "isokit")
        let atlas = root.appendingPathComponent("Kit.atlas")
        for facing in ["ne", "nw", "se", "sw"] {
            for frame in 0 ..< 8 where !(facing == "nw" && frame == 5) {
                try writePNG(
                    image(width: 32, height: 32) { x, y in (1 ..< 31).contains(x) && y < 31 ? wall : nil },
                    to: atlas.appendingPathComponent("carrier-sack-\(facing)-\(frame).png")
                )
                try writePNG(
                    image(width: 64, height: 64) { x, y in (1 ..< 63).contains(x) && y < 63 ? wall : nil },
                    to: atlas.appendingPathComponent("carrier-sack-\(facing)-\(frame)@2x.png")
                )
            }
        }

        let failures = try SpriteContentGate.inspect(resourcesRoot: root, coherenceMaxDistance: 0.9)

        #expect(failures == [.init(file: "carrier-sack-nw-5.png", reason: .walkerFramesMissing)])
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

    @Test("a sprite belongs to the brief whose Sprites section lists it, before any prefix match")
    func sheetListBeatsPrefix() {
        let catalog = GateCatalog(
            entries: [.init(id: "building-house", source: "isokit"), .init(id: "building-house-renaissance", source: "procedural")],
            spriteNames: ["building-house-renaissance": ["building-house-renaissance", "building-house-tier3-renaissance"]]
        )
        #expect(catalog.entry(forSprite: "building-house-tier3-renaissance.png")?.id == "building-house-renaissance")
        #expect(catalog.entry(forSprite: "building-house-tier2.png")?.id == "building-house")
    }

    @Test("a brief is migrated whatever its front-matter order and spacing, and lists its sprite names")
    func migratedBriefsParseLoosely() throws {
        let markdown = "---\nid = \"building-house\"\nsource=  \"isokit\"\n---\n## Sprites\n"
            + "- `building-house` — base\n- `building-house-tier2`\n## Recipe\n- `not-a-sprite`\n"
        let entry = GateCatalog.parse(id: "building-house", markdown: markdown)
        #expect(entry.isMigrated)
        let catalog = try GateCatalog(
            entries: [entry],
            spriteNames: ["building-house": GateCatalog.spriteNames(in: markdown, id: "building-house")]
        )
        #expect(catalog.migratedSpriteNames == ["building-house", "building-house-tier2"])
    }

    @Test("a brief whose sprites cannot be read stops the gate instead of dropping out")
    func unreadableBriefsAreErrors() throws {
        // An empty list, and a name outside the sprite-name grammar.
        for sprites in ["", "- `Building House`"] {
            let root = temporaryResources()
            try writeBrief(root, id: "building-house", source: "isokit", sprites: sprites)
            #expect(throws: GateCatalog.UnreadableBrief.self) { try GateCatalog.load(resourcesRoot: root) }
        }
        // Trailing spaces and CRLF line ends still read.
        let crlf = "## Sprites \r\n\r\n- `building-house` — base\r\n"
        #expect(try GateCatalog.spriteNames(in: crlf, id: "building-house") == ["building-house"])
    }

    @Test("two briefs listing the same sprite are rejected, since its owner would be arbitrary")
    func duplicateSheetOwnersAreRejected() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "building-house", source: "isokit", sprites: "- `building-house-tier2`")
        try writeBrief(root, id: "building-house-tier2", source: "procedural", sprites: "- `building-house-tier2`")
        #expect(throws: GateCatalog.DuplicateSpriteNames(names: ["building-house-tier2"])) {
            try GateCatalog.load(resourcesRoot: root)
        }
    }

    @Test("a brief that lists its own sprite twice is not a duplicate owner")
    func briefListingASpriteTwiceLoads() throws {
        let root = temporaryResources()
        try writeBrief(root, id: "building-house", source: "isokit", sprites: "- `building-house`\n- `building-house`")
        #expect(try GateCatalog.load(resourcesRoot: root).migratedSpriteNames == ["building-house"])
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
