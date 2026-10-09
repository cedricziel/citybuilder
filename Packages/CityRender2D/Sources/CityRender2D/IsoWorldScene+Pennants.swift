import CityCore
import CoreGraphics
import Foundation
import SpriteKit

/// Rival pennants drawn in code. Spec: `rendering-2_5d` / Rival
/// buildings fly a pennant.
extension IsoWorldScene {
    static let pennantNodeName = "rival-pennant"
    static let pennantColourKey = "pennantColour"

    private static var pennantTextures: [String: SKTexture] = [:]

    /// A 1×6 px dark pole with a 5×3 px triangle in `colourHex`, drawn
    /// once per colour.
    static func pennantTexture(colourHex: String) -> SKTexture {
        if let cached = pennantTextures[colourHex] { return cached }
        let texture = drawPennant(colourHex: colourHex).map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = .nearest
        pennantTextures[colourHex] = texture
        return texture
    }

    /// The pennant child for a rival building, at the top-left of
    /// `sprite` and above it.
    static func makePennantNode(colourHex: String, on sprite: SKSpriteNode) -> SKNode {
        let pennant = SKSpriteNode(texture: pennantTexture(colourHex: colourHex))
        pennant.name = pennantNodeName
        pennant.anchorPoint = CGPoint(x: 0, y: 1)
        pennant.position = CGPoint(x: -sprite.size.width / 2, y: sprite.size.height)
        pennant.zPosition = 1
        pennant.userData = [pennantColourKey: colourHex]
        return pennant
    }

    private static func drawPennant(colourHex: String) -> CGImage? {
        let size = 6
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else { return nil }
        // Core Graphics counts rows from the bottom.
        context.setFillColor(CGColor(red: 0.16, green: 0.12, blue: 0.10, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: size))
        context.setFillColor(cgColor(hex: colourHex))
        context.fill(CGRect(x: 1, y: 5, width: 3, height: 1))
        context.fill(CGRect(x: 1, y: 4, width: 5, height: 1))
        context.fill(CGRect(x: 1, y: 3, width: 3, height: 1))
        return context.makeImage()
    }

    private static func cgColor(hex: String) -> CGColor {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return CGColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
