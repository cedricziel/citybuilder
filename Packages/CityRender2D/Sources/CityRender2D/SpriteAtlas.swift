import CityCore
import Foundation
import SpriteKit

/// Resolves terrain and building textures from the host app's main bundle.
/// Sprites live at `Resources/Sprites/<name>.png` and are bundled into the
/// app at build time via project.yml.
///
/// Returns nil when the sprite asset is missing (e.g. in headless tests or
/// when running CityRender2D from a package context without resources).
/// IsoWorldScene falls back to colored diamonds in that case.
public enum SpriteAtlas {
    /// Cache so we only build SKTexture once per asset.
    private nonisolated(unsafe) static var cache: [String: SKTexture] = [:]
    private static let cacheQueue = DispatchQueue(label: "city.spriteatlas.cache")

    public static func terrainTexture(for kind: TerrainType) -> SKTexture? {
        texture(named: "terrain-\(kind.rawValue)")
    }

    public static func buildingTexture(for kind: BuildingKind) -> SKTexture? {
        texture(named: "building-\(kind.rawValue)")
    }

    public enum WalkerFacing: String, CaseIterable {
        case ne, se, sw, nw
    }

    /// Returns the two-frame walk cycle for a given facing. nil if any
    /// frame is missing (graceful fallback to a static sprite or nothing).
    public static func walkerAnimation(facing: WalkerFacing) -> [SKTexture]? {
        var frames: [SKTexture] = []
        for frame in 0 ... 1 {
            guard let tex = texture(named: "walker-\(facing.rawValue)-\(frame)") else {
                return nil
            }
            frames.append(tex)
        }
        return frames
    }

    private static func texture(named name: String) -> SKTexture? {
        var hit: SKTexture?
        cacheQueue.sync { hit = cache[name] }
        if let hit { return hit }

        // Try the main bundle first (apps that bundle Resources/Sprites/).
        let bundles: [Bundle] = [.main]
        for bundle in bundles {
            #if canImport(UIKit)
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                let texture = SKTexture(image: image)
                texture.filteringMode = .nearest
                cacheQueue.sync { cache[name] = texture }
                return texture
            }
            #elseif canImport(AppKit)
            if let image = bundle.image(forResource: name) {
                let texture = SKTexture(image: image)
                texture.filteringMode = .nearest
                cacheQueue.sync { cache[name] = texture }
                return texture
            }
            #endif
        }
        return nil
    }
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
