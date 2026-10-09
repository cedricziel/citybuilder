import CityCore
import SpriteKit
import SwiftUI

/// Building sprites for the build rail, drawer and tool strip, read from
/// the `Buildings` atlas with the same crisp interpolation as the good
/// icons. Falls back to an SF Symbol when the atlas lacks the texture,
/// which is always the case in package tests.
public enum BuildingIconLoader {
    public static let atlasName = "Buildings"

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

    public static func image(for kind: BuildingKind) -> Image {
        let atlas = SKTextureAtlas(named: atlasName)
        let name = textureName(for: kind)
        let names = Set(atlas.textureNames)
        guard names.contains(name) || names.contains(name + ".png") else {
            return Image(systemName: fallbackSymbolName(for: kind))
        }
        let cgImage = atlas.textureNamed(name).cgImage()
        return Image(decorative: cgImage, scale: 1).interpolation(GoodIconLoader.pixelArtInterpolation)
    }
}
