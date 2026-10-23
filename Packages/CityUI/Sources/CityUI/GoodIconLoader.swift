import CityCore
import CityRender2D
import Foundation
import SpriteKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads the goods icons into SwiftUI `Image`s for the HUD stocks row.
/// Falls back to an SF Symbol when a good has no icon so the row never
/// goes blank.
///
/// In the app, Xcode compiles `Kit.atlas/` into `Kit.atlasc`, so the
/// loose PNGs are gone and the icon comes from the `Kit`
/// `SKTextureAtlas`. The URL route stays for tests that point at temp
/// PNGs. The icons are anti-aliased SVG renders, so both scale smoothly,
/// as the SpriteKit scene filters them.
public enum GoodIconLoader {
    /// Source the resolved Image came from. `loaded` carries the URL
    /// the loader used so tests can assert routing without rendering.
    public enum Origin: Equatable, Sendable {
        case loaded(URL)
        case atlas(name: String)
        case fallback
    }

    /// Compiled texture atlas that holds the `good-*` icons.
    public static let atlasName = SpriteAtlasRouting.kitAtlasName

    private static func textureName(for good: Good) -> String {
        "good-\(good.rawValue)"
    }

    public static func origin(for good: Good, atlas: SKTextureAtlas) -> Origin {
        // Compiled atlases list names with the `.png` extension.
        let name = textureName(for: good)
        let names = Set(atlas.textureNames)
        return names.contains(name) || names.contains(name + ".png") ? .atlas(name: atlasName) : .fallback
    }

    /// SF Symbol name used when a good's PNG can't be resolved.
    public static let fallbackSymbolName = "cube.fill"

    /// Interpolation for the goods icons: the HUD draws the 24-point
    /// icons at 16 points, and smooth scaling keeps the anti-aliased
    /// edges clean.
    public static let interpolation: Image.Interpolation = .high

    /// Interpolation for pixel art, such as a legacy building sprite:
    /// nearest-neighbor keeps the pixels crisp instead of blurring.
    public static let pixelArtInterpolation: Image.Interpolation = .none

    /// Resolves the asset URL for a good — defaults to the main bundle
    /// lookup. Tests inject their own resolver to point at temp PNGs.
    public typealias URLResolver = @Sendable (Good) -> URL?

    public static func origin(for good: Good, resolveURL: URLResolver) -> Origin {
        if let url = resolveURL(good) {
            return .loaded(url)
        }
        return .fallback
    }

    public static func origin(for good: Good) -> Origin {
        origin(for: good, resolveURL: mainBundleResolver)
    }

    public static func image(for good: Good) -> Image {
        let atlas = SKTextureAtlas(named: atlasName)
        guard origin(for: good, atlas: atlas) != .fallback else {
            return image(for: good, resolveURL: mainBundleResolver)
        }
        let cgImage = atlas.textureNamed(textureName(for: good)).cgImage()
        return Image(decorative: cgImage, scale: 1).interpolation(interpolation)
    }

    public static func image(for good: Good, resolveURL: URLResolver) -> Image {
        switch origin(for: good, resolveURL: resolveURL) {
        case let .loaded(url):
            return loadImage(at: url) ?? fallbackImage
        case .atlas, .fallback:
            return fallbackImage
        }
    }

    private static var fallbackImage: Image {
        Image(systemName: fallbackSymbolName)
    }

    private static let mainBundleResolver: URLResolver = { good in
        Bundle.main.url(forResource: "good-\(good.rawValue)", withExtension: "png")
    }

    private static func loadImage(at url: URL) -> Image? {
        #if canImport(UIKit)
        guard let bitmap = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: bitmap).interpolation(interpolation)
        #elseif canImport(AppKit)
        guard let bitmap = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: bitmap).interpolation(interpolation)
        #else
        return nil
        #endif
    }
}
