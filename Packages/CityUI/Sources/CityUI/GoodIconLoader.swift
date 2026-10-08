import CityCore
import Foundation
import SpriteKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads pixel-art good icons into SwiftUI `Image`s for the HUD stocks
/// row. Falls back to an SF Symbol when a good has no icon so the row
/// never goes blank.
///
/// In the app, Xcode compiles `Icons.atlas/` into `Icons.atlasc`, so
/// the loose PNGs are gone and the icon comes from the `Icons`
/// `SKTextureAtlas`. The URL route stays for tests that point at temp
/// PNGs. Both render with nearest-neighbor interpolation, the same
/// crisp pixel-art mode the SpriteKit scene uses.
public enum GoodIconLoader {
    /// Source the resolved Image came from. `loaded` carries the URL
    /// the loader used so tests can assert routing without rendering.
    public enum Origin: Equatable, Sendable {
        case loaded(URL)
        case atlas(name: String)
        case fallback
    }

    /// Compiled texture atlas that holds the `good-*` icons.
    public static let atlasName = "Icons"

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

    /// Interpolation mode applied to every loaded pixel-art image. The
    /// HUD chips scale at any DPI; nearest-neighbor keeps the pixels
    /// crisp instead of blurring.
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
        return Image(decorative: cgImage, scale: 1).interpolation(pixelArtInterpolation)
    }

    public static func image(for good: Good, resolveURL: URLResolver) -> Image {
        switch origin(for: good, resolveURL: resolveURL) {
        case let .loaded(url):
            return loadPixelArtImage(at: url) ?? fallbackImage
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

    private static func loadPixelArtImage(at url: URL) -> Image? {
        #if canImport(UIKit)
        guard let bitmap = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: bitmap).interpolation(pixelArtInterpolation)
        #elseif canImport(AppKit)
        guard let bitmap = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: bitmap).interpolation(pixelArtInterpolation)
        #else
        return nil
        #endif
    }
}
