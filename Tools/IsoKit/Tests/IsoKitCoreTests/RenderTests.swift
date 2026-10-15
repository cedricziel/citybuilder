import CoreGraphics
import Foundation
import ImageIO
import Metal
import Testing
@testable import IsoKitCore

/// Tests that need a GPU. CI sets ISOKIT_SKIP_RENDER=1: renders vary slightly between runs and
/// machines, so CI never renders (design D5).
enum RenderGate {
    static var enabled: Bool {
        ProcessInfo.processInfo.environment["ISOKIT_SKIP_RENDER"] != "1" && MTLCreateSystemDefaultDevice() != nil
    }
}

@Suite(.enabled(if: RenderGate.enabled))
struct RenderTests {
    @Test("scenario: A 2×2 house renders 128 points wide")
    func houseRendersOneTwentyEightWide() throws {
        let recipe = try #require(Recipes.all.first { $0.id == "building-house" })
        let image = try Renderer.image(recipe.scene(stage: .finished), cell: recipe.cell, scale: 1)
        #expect(image.width == 128)
        let lowest = try #require(PixelScan.lowestOpaqueRow(image))
        #expect(lowest == image.height - 1, "lowest opaque row \(lowest) of \(image.height)")
        let span = try #require(PixelScan.opaqueSpan(image, row: lowest))
        #expect(abs((span.lowerBound + span.upperBound) / 2 - 64) <= 2)
    }

    @Test("scenario: Sawmill sails turn across operational frames")
    func sawmillSailsTurn() throws {
        let recipe = try #require(Recipes.all.first { $0.id == "building-sawmill" })
        #expect(recipe.operationalFrames == 4)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("isokit-sails-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try RenderJob(recipes: [recipe], output: dir, scales: [1]).run()
        let idle = try PixelScan.rgba(dir.appendingPathComponent("building-sawmill.png"))
        let frames = try (0 ..< 4).map { try PixelScan.rgba(dir.appendingPathComponent("building-sawmill-operational-\($0).png")) }
        for (index, frame) in frames.enumerated() {
            #expect(frame != idle, "operational-\(index) shows no sails")
            #expect(frame != frames[(index + 1) % 4], "operational-\(index) and the next frame are identical")
        }
        // Away from the sails the frame is the idle sprite: the top-left 30x30 corner has no sails.
        for frame in frames {
            #expect(PixelScan.region(frame, width: 128, rows: 0 ..< 30, columns: 0 ..< 30)
                == PixelScan.region(idle, width: 128, rows: 0 ..< 30, columns: 0 ..< 30))
        }
    }

    @Test("@2x renders are exactly twice the @1x size")
    func twoXIsDouble() throws {
        let recipe = try #require(Recipes.all.first { $0.id == "building-forester" })
        let one = try Renderer.image(recipe.scene(stage: .finished), cell: recipe.cell, scale: 1)
        let two = try Renderer.image(recipe.scene(stage: .finished), cell: recipe.cell, scale: 2)
        #expect(two.width == one.width * 2 && two.height == one.height * 2)
    }
}

enum PixelScan {
    static func alpha(_ image: CGImage) -> [UInt8] {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return stride(from: 3, to: data.count, by: 4).map { data[$0] }
    }

    /// RGBA bytes of a PNG file, rows from the top.
    static func rgba(_ url: URL) throws -> [UInt8] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw CocoaError(.fileReadCorruptFile) }
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }

    /// Bytes of a rectangle of an RGBA buffer whose rows are `width` pixels wide.
    static func region(_ data: [UInt8], width: Int, rows: Range<Int>, columns: Range<Int>) -> [UInt8] {
        rows.flatMap { row in data[(row * width + columns.lowerBound) * 4 ..< (row * width + columns.upperBound) * 4] }
    }

    /// Row index counted from the top.
    static func lowestOpaqueRow(_ image: CGImage) -> Int? {
        let alpha = alpha(image)
        return (0 ..< image.height).last { row in (0 ..< image.width).contains { alpha[row * image.width + $0] > 128 } }
    }

    static func opaqueSpan(_ image: CGImage, row: Int) -> ClosedRange<Int>? {
        let alpha = alpha(image)
        let columns = (0 ..< image.width).filter { alpha[row * image.width + $0] > 128 }
        guard let first = columns.first, let last = columns.last else { return nil }
        return first ... last
    }
}
