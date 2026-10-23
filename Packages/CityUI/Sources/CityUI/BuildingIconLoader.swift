import CityCore
import CityRender2D
import SpriteKit
import SwiftUI

/// Building sprites for the build rail, drawer and tool strip, read from the
/// atlas the sprite routes to (`SpriteAtlasRouting`). Art-kit renders scale
/// smoothly; legacy pixel art keeps the good icons' crisp interpolation.
/// Falls back to an SF Symbol when the atlas lacks the texture, which is
/// always the case in package tests.
public enum BuildingIconLoader {
    /// Port and shipyard ship one sprite per facing; the rail shows the
    /// south-facing one.
    public static func textureName(for kind: BuildingKind) -> String {
        switch kind {
        case .port, .shipyard: "building-\(kind.rawValue)-s"
        default: "building-\(kind.rawValue)"
        }
    }

    static func atlasName(for kind: BuildingKind) -> String? {
        SpriteAtlasRouting.atlasName(for: textureName(for: kind))
    }

    /// Smooth for linearly filtered kit renders, which nearest scaling turns jaggy; crisp for pixel art.
    public static func interpolation(for kind: BuildingKind) -> Image.Interpolation {
        TextureFiltering.mode(for: textureName(for: kind)) == .linear ? .high : GoodIconLoader.pixelArtInterpolation
    }

    public static func fallbackSymbolName(for kind: BuildingKind) -> String {
        kind == .road ? "road.lanes" : "building.2.fill"
    }

    /// One image per kind, built on first use: view bodies ask for these on
    /// every 10 Hz HUD refresh.
    @MainActor private static var cache: [BuildingKind: Image] = [:]

    @MainActor static var cachedKinds: Set<BuildingKind> {
        Set(cache.keys)
    }

    @MainActor
    public static func image(for kind: BuildingKind) -> Image {
        if let cached = cache[kind] { return cached }
        let image = loadImage(for: kind)
        cache[kind] = image
        return image
    }

    @MainActor
    private static func loadImage(for kind: BuildingKind) -> Image {
        let name = textureName(for: kind)
        guard let atlasName = atlasName(for: kind) else { return Image(systemName: fallbackSymbolName(for: kind)) }
        let atlas = SKTextureAtlas(named: atlasName)
        let names = Set(atlas.textureNames)
        guard names.contains(name) || names.contains(name + ".png") else {
            return Image(systemName: fallbackSymbolName(for: kind))
        }
        let cgImage = atlas.textureNamed(name).cgImage()
        return Image(decorative: croppedToBuilding(cgImage), scale: 1).interpolation(interpolation(for: kind))
    }

    /// The lowest alpha of a building pixel. The baked shadow is translucent (the rig's shadow colour
    /// is 55% opaque, about 140 of 255) and the building's anti-aliased edges stay above 230.
    static let buildingAlpha: UInt8 = 192

    /// `image` cut to its building and plot. A sprite is wider than its building where its shadow needs
    /// room, and an icon scaled to fit would shrink by that margin, so the shadow is left out of the bounds.
    static func croppedToBuilding(_ image: CGImage) -> CGImage {
        let width = image.width, height = image.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = context.data
        else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let alpha = data.assumingMemoryBound(to: UInt8.self)
        var minX = width, maxX = -1, minY = height, maxY = -1
        for row in 0 ..< height {
            for column in 0 ..< width where alpha[(row * width + column) * 4 + 3] >= buildingAlpha {
                minX = min(minX, column)
                maxX = max(maxX, column)
                minY = min(minY, row)
                maxY = max(maxY, row)
            }
        }
        guard maxX >= minX, maxY >= minY else { return image }
        // The bitmap's rows run top to bottom, as `cropping(to:)` expects.
        return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)) ?? image
    }
}
