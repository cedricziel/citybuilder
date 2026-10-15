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
        return Image(decorative: cgImage, scale: 1).interpolation(interpolation(for: kind))
    }
}
