import CityCore
import Foundation
import SpriteKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Resolves terrain, building, and walker textures from the host app's
/// main bundle. Sprites live at `Resources/Sprites/<name>.png` and are
/// bundled into the app at build time via project.yml.
///
/// Returns nil when an asset is missing (e.g. in headless tests or when
/// running CityRender2D from a package context without resources).
/// IsoWorldScene falls back to colored diamonds in that case.
public enum SpriteAtlas {
    private nonisolated(unsafe) static var cache: [String: SKTexture] = [:]
    private static let cacheQueue = DispatchQueue(label: "city.spriteatlas.cache")

    public enum WalkerFacing: String, CaseIterable, Hashable, Sendable {
        case ne, se, sw, nw
    }

    public static func terrainTexture(for kind: TerrainType) -> SKTexture? {
        texture(named: "terrain-\(kind.rawValue)")
    }

    public static func buildingTexture(for kind: BuildingKind) -> SKTexture? {
        texture(named: "building-\(kind.rawValue)")
    }

    /// Two-frame walk cycle for a given facing. Backed by `frames(for:)`
    /// so all multi-frame lookups share one code path.
    public static func walkerAnimation(facing: WalkerFacing) -> [SKTexture]? {
        frames(for: .walker(facing))
    }

    /// Multi-frame lookup for any `AnimationKey`. Returns `nil` if any
    /// declared frame asset is missing — the caller falls back to a
    /// static sprite per design D8.
    public static func frames(for key: SpriteAnimation.AnimationKey) -> [SKTexture]? {
        guard let entry = SpriteAnimation.entry(for: key) else { return nil }
        var frames: [SKTexture] = []
        frames.reserveCapacity(entry.frameCount)
        for frame in 0 ..< entry.frameCount {
            let name = SpriteAnimation.assetName(for: key, frame: frame)
            guard let tex = texture(named: name) else { return nil }
            frames.append(tex)
        }
        return frames
    }

    /// Internal: load and cache a single named texture. Cache key is the
    /// asset name; the same PNG resolves once across all callers (static
    /// terrain/building lookups, multi-frame lookups, walker frames).
    static func texture(named name: String) -> SKTexture? {
        var hit: SKTexture?
        cacheQueue.sync { hit = cache[name] }
        if let hit { return hit }

        #if canImport(UIKit)
        if let image = UIImage(named: name, in: .main, compatibleWith: nil) {
            let texture = SKTexture(image: image)
            texture.filteringMode = .nearest
            cacheQueue.sync { cache[name] = texture }
            return texture
        }
        #elseif canImport(AppKit)
        if let image = Bundle.main.image(forResource: name) {
            let texture = SKTexture(image: image)
            texture.filteringMode = .nearest
            cacheQueue.sync { cache[name] = texture }
            return texture
        }
        #endif
        return nil
    }
}
