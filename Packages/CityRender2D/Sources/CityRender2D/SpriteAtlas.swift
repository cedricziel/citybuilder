import CityCore
import Foundation
import SpriteKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Maps a sprite name to the category atlas that owns it. The routing
/// table is fixed by the sprite-asset-pipeline naming grammar: a name's
/// prefix uniquely determines its atlas. New prefixes (e.g. `ship-` once
/// `add-archipelago-and-sea` lands) extend this table.
public enum SpriteAtlasRouting {
    public static let terrainAtlasName = "Terrain"
    public static let buildingsAtlasName = "Buildings"
    public static let unitsAtlasName = "Units"

    /// Returns the atlas name for a given sprite name, or nil if the
    /// prefix is unknown.
    public static func atlasName(for spriteName: String) -> String? {
        if spriteName.hasPrefix("terrain-") { return terrainAtlasName }
        if spriteName.hasPrefix("building-") { return buildingsAtlasName }
        if spriteName.hasPrefix("walker-") { return unitsAtlasName }
        if spriteName.hasPrefix("ship-") { return unitsAtlasName }
        return nil
    }

    /// All atlas names known to the routing table. Used by the
    /// asset-presence check and the lazy-construction probe.
    public static let allAtlasNames: [String] = [
        terrainAtlasName, buildingsAtlasName, unitsAtlasName
    ]
}

/// Resolves terrain, building, and walker textures from the host app's
/// main bundle. Sprites live in three category atlases under
/// `Resources/` (`Terrain.atlas/`, `Buildings.atlas/`, `Units.atlas/`),
/// which Xcode packs into single GPU textures at build time. Lookups go
/// through `SKTextureAtlas(named:)` — never `SKTexture(imageNamed:)`.
///
/// Returns nil when an asset is missing (e.g. in headless tests or when
/// running CityRender2D from a package context without resources).
/// IsoWorldScene falls back to colored diamonds in that case.
public enum SpriteAtlas {
    private nonisolated(unsafe) static var atlasCache: [String: SKTextureAtlas] = [:]
    private nonisolated(unsafe) static var atlasNameSetCache: [String: Set<String>] = [:]
    private nonisolated(unsafe) static var textureCache: [String: SKTexture] = [:]
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

    /// Internal: route a sprite name to its category `SKTextureAtlas`
    /// and return the texture, or nil if the prefix is unknown or the
    /// name is not packed into that atlas (the asset is missing).
    static func texture(named name: String) -> SKTexture? {
        var hit: SKTexture?
        cacheQueue.sync { hit = textureCache[name] }
        if let hit { return hit }

        guard let atlasName = SpriteAtlasRouting.atlasName(for: name) else { return nil }
        let atlas = atlas(forName: atlasName)
        let names = atlasNames(for: atlasName, atlas: atlas)
        // `SKTextureAtlas.textureNames` stores entries with their `.png`
        // extension (the format the compiled `.atlasc` plist uses). The
        // public-facing sprite names in this codebase are extension-less.
        // Accept either form so a future SpriteKit version that strips
        // the extension also resolves cleanly.
        guard names.contains(name) || names.contains(name + ".png") else { return nil }
        let texture = atlas.textureNamed(name)
        texture.filteringMode = .nearest
        cacheQueue.sync { textureCache[name] = texture }
        return texture
    }

    private static func atlas(forName name: String) -> SKTextureAtlas {
        var hit: SKTextureAtlas?
        cacheQueue.sync { hit = atlasCache[name] }
        if let hit { return hit }
        let atlas = SKTextureAtlas(named: name)
        cacheQueue.sync { atlasCache[name] = atlas }
        return atlas
    }

    private static func atlasNames(for atlasName: String, atlas: SKTextureAtlas) -> Set<String> {
        var hit: Set<String>?
        cacheQueue.sync { hit = atlasNameSetCache[atlasName] }
        if let hit { return hit }
        let names = Set(atlas.textureNames)
        cacheQueue.sync { atlasNameSetCache[atlasName] = names }
        return names
    }

    // MARK: - Release-mode placeholder + log-once

    /// 32×32 magenta sprite used as the visible placeholder when a
    /// catalogued sprite name fails to resolve at draw time. Spec:
    /// `rendering-2_5d` / `Missing-sprite fallback in release`.
    public nonisolated(unsafe) static let placeholderTexture: SKTexture = makePlaceholderTexture()

    /// Test-only hook: when set, called instead of `NSLog` for the
    /// first miss observed for each name. Tests use this to assert
    /// the log-once invariant without intercepting the system log.
    nonisolated(unsafe) static var missLogHook: ((String) -> Void)?

    private nonisolated(unsafe) static var loggedMisses: Set<String> = []

    /// Returns the named texture, or `placeholderTexture` if the
    /// lookup fails. The missing name is logged exactly once per
    /// process lifetime so a catalog bug that escaped the debug-only
    /// `assertCatalogComplete()` check still surfaces loudly in
    /// release without crashing the renderer.
    public static func textureOrPlaceholder(named name: String) -> SKTexture {
        if let tex = texture(named: name) { return tex }
        logMissOnce(name)
        return placeholderTexture
    }

    private static func logMissOnce(_ name: String) {
        var shouldLog = false
        cacheQueue.sync { shouldLog = loggedMisses.insert(name).inserted }
        guard shouldLog else { return }
        if let hook = missLogHook {
            hook(name)
        } else {
            NSLog("[CityRender2D] missing sprite: %@", name)
        }
    }

    private static func makePlaceholderTexture() -> SKTexture {
        let size = CGSize(width: 32, height: 32)
        let rect = CGRect(origin: .zero, size: size)
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.magenta.setFill()
            ctx.fill(rect)
        }
        let texture = SKTexture(image: image)
        #elseif canImport(AppKit)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.magenta.setFill()
        rect.fill()
        image.unlockFocus()
        let texture = SKTexture(image: image)
        #else
        let texture = SKTexture()
        #endif
        texture.filteringMode = .nearest
        return texture
    }

    /// Test-only: clears the per-process miss-log set so a follow-up
    /// test observes the first-miss path.
    static func resetMissLogForTesting() {
        cacheQueue.sync { loggedMisses.removeAll() }
    }

    // MARK: - Catalog & presence validation

    /// Every sprite name the catalog declares: static terrain and
    /// building bases, every multi-frame animation entry, every walker
    /// facing × frame. Sourced from `SpriteAnimation` plus the static
    /// base names for each kind.
    public static var catalogSpriteNames: [String] {
        var names: [String] = []

        for kind in TerrainType.allCases {
            names.append("terrain-\(kind.rawValue)")
            if let entry = SpriteAnimation.entry(for: .terrain(kind)) {
                for frame in 0 ..< entry.frameCount {
                    names.append(SpriteAnimation.assetName(for: .terrain(kind), frame: frame))
                }
            }
        }

        for kind in BuildingKind.allCases {
            let isShore = SpriteName.shorePlacementKindRawValues.contains(kind.rawValue)
            if isShore {
                // Shore-placement kinds use the orientation-bearing
                // grammar: 4 orientations × {idle, 3 constructing
                // frames, 2 operational frames} = 24 entries per kind.
                for orientation in SpriteName.shoreOrientations {
                    let stem = "building-\(kind.rawValue)-\(orientation)"
                    names.append(stem)
                    for frame in 0 ..< 3 {
                        names.append("\(stem)-constructing-\(frame)")
                    }
                    for frame in 0 ..< 2 {
                        names.append("\(stem)-operational-\(frame)")
                    }
                }
                continue
            }
            names.append("building-\(kind.rawValue)")
            if let opEntry = SpriteAnimation.entry(for: .buildingOperational(kind)) {
                for frame in 0 ..< opEntry.frameCount {
                    names.append(
                        SpriteAnimation.assetName(for: .buildingOperational(kind), frame: frame)
                    )
                }
            }
            if let conEntry = SpriteAnimation.entry(for: .buildingConstructing(kind)) {
                for frame in 0 ..< conEntry.frameCount {
                    names.append(
                        SpriteAnimation.assetName(for: .buildingConstructing(kind), frame: frame)
                    )
                }
            }
        }

        for facing in WalkerFacing.allCases {
            if let entry = SpriteAnimation.entry(for: .walker(facing)) {
                for frame in 0 ..< entry.frameCount {
                    names.append(SpriteAnimation.assetName(for: .walker(facing), frame: frame))
                }
            }
        }

        // Ship sprites: 8 facings × 2 frames = 16 entries.
        for facing in SpriteName.shipFacings {
            for frame in 0 ..< 2 {
                names.append("ship-\(facing)-\(frame)")
            }
        }

        return names
    }

    /// Returns the subset of `names` that do not resolve to a packed
    /// atlas texture. A name is considered missing if its prefix maps
    /// to an unknown atlas OR the atlas does not list the name in its
    /// `textureNames`. Used by the DEBUG `assertCatalogComplete()`
    /// startup check; also useful as a direct test surface.
    public static func missingSprites(in names: [String]) -> [String] {
        names.filter { texture(named: $0) == nil }
    }

    #if DEBUG
    /// DEBUG-only: scans the full catalog and fires a `precondition`
    /// listing the missing sprite names. Call once from the app shell
    /// at first `SpriteAtlas` use (e.g., from `IsoWorldScene.didMove`).
    /// In release builds this symbol is elided and the renderer's
    /// per-draw magenta placeholder is the only safety net.
    public static func assertCatalogComplete() {
        let missing = missingSprites(in: catalogSpriteNames)
        precondition(
            missing.isEmpty,
            "Sprite catalog is missing assets: \(missing.sorted().joined(separator: ", "))"
        )
    }
    #endif

    // MARK: - Test-only state probes

    /// Test-only: returns true once the named category atlas has been
    /// constructed (i.e. a lookup against that category has happened).
    static func isAtlasConstructed(named name: String) -> Bool {
        var hit: SKTextureAtlas?
        cacheQueue.sync { hit = atlasCache[name] }
        return hit != nil
    }

    /// Test-only: clears the lazy atlas cache and the texture cache so
    /// the next lookup re-triggers construction. Tests that observe
    /// lazy-init behavior call this first to get a clean slate.
    static func resetForTesting() {
        cacheQueue.sync {
            atlasCache.removeAll()
            atlasNameSetCache.removeAll()
            textureCache.removeAll()
        }
    }
}
