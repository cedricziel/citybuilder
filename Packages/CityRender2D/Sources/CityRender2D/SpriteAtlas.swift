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
    public static let buildingsAtlasName = "Buildings"
    public static let iconsAtlasName = "Icons"
    /// Art-kit renders, filtered linearly. SpriteKit applies one filtering mode to a whole atlas
    /// page, so they cannot share a page with nearest-filtered pixel art (design D7).
    public static let kitAtlasName = "Kit"

    /// Returns the atlas name for a given sprite name, or nil if the
    /// prefix is unknown.
    public static func atlasName(for spriteName: String) -> String? {
        if TextureFiltering.kitRenderedStems.contains(TextureFiltering.stem(of: spriteName)) { return kitAtlasName }
        // Every terrain family has migrated; the Terrain atlas is retired.
        if spriteName.hasPrefix("terrain-") { return kitAtlasName }
        if spriteName.hasPrefix("building-") { return buildingsAtlasName }
        // Status badges drawn over buildings live in the Buildings atlas.
        if spriteName.hasPrefix("overlay-") { return buildingsAtlasName }
        // People and ships are kit renders; the Units atlas is retired (realistic-walkers).
        if ["walker-", "carrier-", "animal-", "ship-"].contains(where: spriteName.hasPrefix) { return kitAtlasName }
        if spriteName.hasPrefix("good-") { return iconsAtlasName }
        return nil
    }

    /// All atlas names known to the routing table. Used by the
    /// asset-presence check and the lazy-construction probe.
    public static let allAtlasNames: [String] = [
        buildingsAtlasName, iconsAtlasName, kitAtlasName
    ]
}

/// Resolves terrain, building, and walker textures from the host app's
/// main bundle. Sprites live in three category atlases under
/// `Resources/` (`Kit.atlas/`, `Buildings.atlas/`, `Icons.atlas/`),
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

    /// A resident's look. Carriers have their own looks, by load (`carrierAnimation`).
    public enum WalkerLook: String, CaseIterable, Hashable, Sendable {
        case worker, woman

        /// `walker` for the worker, `walker-woman` for the woman.
        var stem: String {
            self == .worker ? "walker" : "walker-\(rawValue)"
        }
    }

    /// An animal's sprite family: what it is and what it does. Spec: realistic-walkers.
    public enum AnimalAction: String, CaseIterable, Hashable, Sendable {
        case sheepWalk = "sheep-walk", sheepGraze = "sheep-graze", cowWalk = "cow-walk", cowGraze = "cow-graze"
        /// A hen pecking.
        case hen

        var stem: String {
            "animal-\(rawValue)"
        }

        /// The point under the animal's feet, where its node anchors: the feet stand off the cell's
        /// bottom and left of its centre, so the stride and the shadow falling right fit. The animal
        /// brief lists the same points (`Anchor:` lines) and a test keeps them equal.
        public var anchor: CGPoint {
            switch self {
            case .sheepWalk, .sheepGraze: CGPoint(x: 14.0 / 34.0, y: 7.0 / 26.0)
            case .cowWalk, .cowGraze: CGPoint(x: 21.0 / 52.0, y: 11.0 / 44.0)
            case .hen: CGPoint(x: 8.0 / 18.0, y: 4.0 / 14.0)
            }
        }
    }

    /// Walker sprites stand 5 pt above the bottom of their 32 pt cell and 4 pt left of its centre, so the
    /// stride and the shadow falling right fit; nodes anchor there. Spec: `rendering-2_5d` / Figures
    /// stand on their feet.
    public static let walkerAnchor = CGPoint(x: 12.0 / 32.0, y: 5.0 / 32.0)

    public static func terrainTexture(for kind: TerrainType) -> SKTexture? {
        texture(named: "terrain-\(kind.rawValue)")
    }

    public static func buildingTexture(for kind: BuildingKind) -> SKTexture? {
        texture(named: "building-\(kind.rawValue)")
    }

    // MARK: - Per-tile art variants

    //
    // Some sprite kinds (mountain, road) ship multiple visually distinct
    // PNGs so a row of mountain tiles isn't a row of clones. Variant 0
    // uses the canonical name (`terrain-mountain.png`); variants 1..N-1
    // use `<stem>-vN.png`. Selection is a deterministic function of the
    // tile coordinate, so replays and snapshots render the same.

    /// Number of art variants per terrain kind. Kinds not listed render
    /// the single canonical sprite.
    public static let terrainVariantCounts: [TerrainType: Int] = [
        .grass: 4,
        .mountain: 4
    ]

    /// Number of art variants per building kind. Only applies to the
    /// idle/operational sprite (not shore-orientation variants, which
    /// already follow their own naming grammar).
    /// Roads used to ship four art variants; they now pick a connection sprite (`RoadLinks`).
    public static let buildingVariantCounts: [BuildingKind: Int] = [:]

    /// Deterministic variant index for a tile coord. Same `(coord, count)`
    /// always returns the same index — required so the snapshot-driven
    /// reconciler doesn't see flicker between frames.
    public static func variantIndex(coord: TileCoordinate, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let hash = tileHash(Int32(truncatingIfNeeded: coord.x), Int32(truncatingIfNeeded: coord.y))
        return Int(hash % UInt32(count))
    }

    /// A well-mixed 32-bit hash of a lattice point, stable across runs and platforms. `salt` picks
    /// an independent stream; salt 0 is the variant hash.
    static func tileHash(_ x: Int32, _ y: Int32, salt: UInt32 = 0) -> UInt32 {
        var hash = UInt32(bitPattern: x) &* 0x9E37_79B1 &+ UInt32(bitPattern: y) &* 0x6D2B_79F5 &+ salt &* 0x85EB_CA6B
        hash ^= hash >> 16
        hash &*= 0x7FEB_352D
        hash ^= hash >> 15
        return hash
    }

    /// Resolves the asset name for a variant. Variant 0 uses the stem
    /// alone so existing single-sprite kinds keep their canonical name.
    public static func variantAssetName(stem: String, variant: Int) -> String {
        variant == 0 ? stem : "\(stem)-v\(variant)"
    }

    /// Variant-aware building texture lookup. Used for non-shore
    /// buildings whose idle sprite has variants (currently: road). Shore
    /// orientations are resolved separately via `ShoreOrientationMath`.
    public static func buildingTextureOrPlaceholder(
        for kind: BuildingKind,
        coord: TileCoordinate
    ) -> SKTexture {
        let count = buildingVariantCounts[kind] ?? 1
        let variant = variantIndex(coord: coord, count: count)
        let name = variantAssetName(stem: "building-\(kind.rawValue)", variant: variant)
        return textureOrPlaceholder(named: name)
    }

    /// The walk cycle of a resident look in a facing; frame 0 is the standing pose. Backed by
    /// `frames(for:)` so all multi-frame lookups share one code path.
    public static func walkerAnimation(facing: WalkerFacing, look: WalkerLook) -> [SKTexture]? {
        frames(for: .walker(facing, look))
    }

    /// An animal's cycle in a facing: walking, grazing or pecking. Frame 0 doubles as standing still.
    public static func animalAnimation(_ action: AnimalAction, facing: WalkerFacing) -> [SKTexture]? {
        frames(for: .animal(action, facing))
    }

    /// The worker's walk cycle.
    public static func walkerAnimation(facing: WalkerFacing) -> [SKTexture]? {
        walkerAnimation(facing: facing, look: .worker)
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
        texture.filteringMode = TextureFiltering.mode(for: name)
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

    /// Logs a missing sprite once per process; a fallback that draws something else still reports it.
    static func logMissOnce(_ name: String) {
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
            // Art variants (grass, rock): variant 0 already added above as
            // the canonical stem; variants 1..N-1 use the `-vN` suffix, with their frames.
            if let variantCount = terrainVariantCounts[kind], variantCount > 1 {
                let frames = SpriteAnimation.entry(for: .terrain(kind))?.frameCount ?? 0
                for variant in 1 ..< variantCount {
                    let name = variantAssetName(stem: "terrain-\(kind.rawValue)", variant: variant)
                    names.append(name)
                    names += (0 ..< frames).map { "\(name)-\($0)" }
                }
            }
        }

        for kind in BuildingKind.allCases {
            let isShore = SpriteName.shorePlacementKindRawValues.contains(kind.rawValue)
            if isShore {
                // Shore-placement kinds use the orientation-bearing
                // grammar: 4 orientations × {idle, 3 constructing
                // frames, their operational frames}.
                for orientation in SpriteName.shoreOrientations {
                    let stem = "building-\(kind.rawValue)-\(orientation)"
                    names.append(stem)
                    for frame in 0 ..< 3 {
                        names.append("\(stem)-constructing-\(frame)")
                    }
                    for frame in 0 ..< (SpriteName.shoreOperationalFrames[kind.rawValue] ?? 2) {
                        names.append("\(stem)-operational-\(frame)")
                    }
                }
                continue
            }
            names.append("building-\(kind.rawValue)")
            // Art variants (road): variant 0 = the canonical stem just
            // appended; variants 1..N-1 use `-vN`. Only applies to
            // non-shore kinds (shore kinds have their own grammar).
            if let variantCount = buildingVariantCounts[kind], variantCount > 1 {
                for variant in 1 ..< variantCount {
                    names.append(
                        variantAssetName(stem: "building-\(kind.rawValue)", variant: variant)
                    )
                }
            }
            if kind == .road {
                names += RoadLinks.allMasks.flatMap { mask in
                    [false, true].map { RoadLink(mask: mask, plaza: $0).assetName }
                }
            }
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

        for key in SpriteAnimation.AnimationKey.figures {
            let frames = SpriteAnimation.entry(for: key)?.frameCount ?? 0
            names += (0 ..< frames).map { SpriteAnimation.assetName(for: key, frame: $0) }
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
