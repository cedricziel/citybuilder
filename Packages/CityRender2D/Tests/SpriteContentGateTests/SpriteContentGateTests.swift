#if canImport(ImageIO)
import Foundation
import ImageIO
import SpriteContentGate
import Testing
import UniformTypeIdentifiers

private let water = Pixel(red: 0x3F, green: 0x6E, blue: 0x94)
private let glint = Pixel(red: 0xA8, green: 0xCC, blue: 0xDD)
private let roof = Pixel(red: 0x8B, green: 0x2E, blue: 0x1F)
private let wall = Pixel(red: 0xD9, green: 0xB0, blue: 0x7A)

private struct Pixel {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}

private func image(
    width: Int = 64,
    height: Int = 32,
    paint: (Int, Int) -> Pixel?
) -> RGBAImage {
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0 ..< height {
        for x in 0 ..< width {
            guard let pixel = paint(x, y) else { continue }
            let offset = (y * width + x) * 4
            bytes[offset] = pixel.red
            bytes[offset + 1] = pixel.green
            bytes[offset + 2] = pixel.blue
            bytes[offset + 3] = 255
        }
    }
    return RGBAImage(width: width, height: height, rgba: bytes)
}

private func insideDiamond(_ x: Int, _ y: Int, width: Int = 64, height: Int = 32) -> Bool {
    DiamondMask.contains(x: x, y: y, width: width, height: height)
}

private func waterFrame(glintPhase: Int) -> RGBAImage {
    image { x, y in
        guard insideDiamond(x, y) else { return nil }
        return (x + y * 3 + glintPhase) % 11 == 0 ? glint : water
    }
}

private func houseSprite(shiftX: Int = 0, smoke: Bool = false) -> RGBAImage {
    image { x, y in
        if smoke, (34 ..< 37).contains(x), (0 ..< 4).contains(y) {
            return glint
        }
        guard (20 + shiftX ..< 44 + shiftX).contains(x), (4 ..< 28).contains(y) else { return nil }
        return y < 14 ? roof : wall
    }
}

private func writePNG(_ image: RGBAImage, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let provider = try #require(CGDataProvider(data: Data(image.rgba) as CFData))
    let cg = try #require(CGImage(
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ))
    let dest = try #require(CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ))
    CGImageDestinationAddImage(dest, cg, nil)
    #expect(CGImageDestinationFinalize(dest))
}

private func temporaryResources() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("sprite-gate-\(UUID().uuidString)")
}

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

    @Test("scenario: verification fails on a content defect even when bytes reproduce")
    func executableExitsNonZeroOnDefect() throws {
        let root = temporaryResources()
        try writePNG(waterFrame(glintPhase: 0), to: root.appendingPathComponent("Terrain.atlas/terrain-water.png"))
        try writePNG(image { _, _ in nil }, to: root.appendingPathComponent("Terrain.atlas/terrain-water-2.png"))

        let report = try SpriteContentGate.run(arguments: [root.path, "--max-distance", "0.2"])

        #expect(report.exitCode != 0)
        #expect(report.output.contains("terrain-water-2.png frame_empty"))
    }
}
#endif
