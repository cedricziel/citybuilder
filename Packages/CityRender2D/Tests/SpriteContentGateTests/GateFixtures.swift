#if canImport(ImageIO)
import Foundation
import ImageIO
import SpriteContentGate
import Testing
import UniformTypeIdentifiers

// Shared PNG fixtures for the content-gate tests.

let water = Pixel(red: 0x3F, green: 0x6E, blue: 0x94)
let glint = Pixel(red: 0xA8, green: 0xCC, blue: 0xDD)
let roof = Pixel(red: 0x8B, green: 0x2E, blue: 0x1F)
let wall = Pixel(red: 0xD9, green: 0xB0, blue: 0x7A)
let outline = Pixel(red: 0x1A, green: 0x14, blue: 0x10)

struct Pixel {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}

func image(
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

func insideDiamond(_ x: Int, _ y: Int, width: Int = 64, height: Int = 32) -> Bool {
    DiamondMask.contains(x: x, y: y, width: width, height: height)
}

func waterFrame(glintPhase: Int) -> RGBAImage {
    image { x, y in
        guard insideDiamond(x, y) else { return nil }
        return (x + y * 3 + glintPhase) % 11 == 0 ? glint : water
    }
}

func houseSprite(shiftX: Int = 0, smoke: Bool = false) -> RGBAImage {
    image { x, y in
        if smoke, (34 ..< 37).contains(x), (0 ..< 4).contains(y) {
            return glint
        }
        guard (20 + shiftX ..< 44 + shiftX).contains(x), (4 ..< 32).contains(y) else { return nil }
        if y == 31 || x == 43 + shiftX { return outline }
        return y < 14 ? roof : wall
    }
}

func writePNG(_ image: RGBAImage, to url: URL) throws {
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

func temporaryResources() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("sprite-gate-\(UUID().uuidString)")
}
#endif
