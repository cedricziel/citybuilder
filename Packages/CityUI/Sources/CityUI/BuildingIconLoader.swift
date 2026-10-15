import CityCore
import SpriteKit
import SwiftUI

/// Building sprites for the build rail, drawer and tool strip, read from
/// the `Buildings` atlas, or `Kit` for art-kit renders, with the same crisp
/// interpolation as the good icons. Falls back to an SF Symbol when neither
/// atlas has the texture, which is always the case in package tests.
public enum BuildingIconLoader {
    /// Legacy pixel art first, then the art kit's own atlas (mirrors `SpriteAtlasRouting`).
    public static let atlasNames = ["Buildings", "Kit"]

    /// Port and shipyard ship one sprite per facing; the rail shows the
    /// south-facing one.
    public static func textureName(for kind: BuildingKind) -> String {
        switch kind {
        case .port, .shipyard: "building-\(kind.rawValue)-s"
        default: "building-\(kind.rawValue)"
        }
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
        for atlasName in atlasNames {
            let atlas = SKTextureAtlas(named: atlasName)
            let names = Set(atlas.textureNames)
            guard names.contains(name) || names.contains(name + ".png") else { continue }
            let cgImage = atlas.textureNamed(name).cgImage()
            return Image(decorative: cgImage, scale: 1).interpolation(GoodIconLoader.pixelArtInterpolation)
        }
        return Image(systemName: fallbackSymbolName(for: kind))
    }
}
