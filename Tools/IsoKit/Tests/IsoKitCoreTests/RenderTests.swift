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
