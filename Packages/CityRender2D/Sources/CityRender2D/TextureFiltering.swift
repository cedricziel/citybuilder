import CityCore
import SpriteKit

/// rendering-2_5d: World textures are @2x and linearly filtered (design D7).
///
/// Art-kit sprites, goods icons included, are anti-aliased renders shipped with `@2x` twins, so they
/// filter linearly. The status badges are pixel art and keep `.nearest`; linear filtering would blur
/// them.
public enum TextureFiltering {
    /// Sprite stems the art kit renders: one per building look, terrain kind or transition pair, the
    /// way the migrated briefs' Sprites lists name them. A test keeps this set equal to the catalog.
    /// States, frames, variants and transition masks are stripped before the lookup, so
    /// `building-house-constructing-1` matches `building-house`. The match is exact:
    /// `building-house-mediterranean` is its own (legacy) brief.
    public static let kitRenderedStems: Set<String> = Set([
        "building-house", "building-house-tier2", "building-house-tier3", "building-town-center",
        "terrain-grass", "terrain-grass-autumn", "terrain-grass-winter", "terrain-beach", "terrain-water",
        "terrain-forest-sparse", "terrain-forest-sparse-autumn", "terrain-forest-sparse-winter",
        "terrain-forest-medium", "terrain-forest-medium-autumn", "terrain-forest-medium-winter",
        "terrain-forest-dense", "terrain-forest-dense-autumn", "terrain-forest-dense-winter",
        "terrain-mountain-sparse", "terrain-mountain-sparse-winter", "terrain-mountain-medium", "terrain-mountain-medium-winter",
        "terrain-mountain-dense", "terrain-mountain-dense-winter", "terrain-mountain-peak", "terrain-mountain-peak-winter",
        "terrain-grass-beach", "terrain-beach-water",
        "building-road", "building-road-plaza",
        "building-lumberjack-hut", "building-forester", "building-farm", "building-grain-farm", "building-mine",
        "building-hop-garden", "building-vineyard", "building-tea-garden", "building-coffee-grove",
        "building-sawmill", "building-bakery", "building-windmill", "building-quern-house", "building-charcoal-burner",
        "building-smelter", "building-toolsmith", "building-brewery", "building-winery", "building-roastery",
        "building-steam-engine", "building-power-plant",
        "building-warehouse", "building-library", "building-mead-hall", "building-forum", "building-tea-house",
        "building-temple-garden", "building-caravanserai", "building-monument", "building-guild-hall", "building-gallery",
        "building-warehouse-east-asian", "building-warehouse-mediterranean", "building-warehouse-middle-eastern",
        "building-library-east-asian", "building-library-mediterranean", "building-library-middle-eastern",
        "building-port-n", "building-port-e", "building-port-s", "building-port-w",
        "building-shipyard-n", "building-shipyard-e", "building-shipyard-s", "building-shipyard-w",
        "ship-n", "ship-ne", "ship-e", "ship-se", "ship-s", "ship-sw", "ship-w", "ship-nw",
        "building-house-east-asian", "building-house-tier2-east-asian", "building-house-tier3-east-asian",
        "building-house-mediterranean", "building-house-tier2-mediterranean", "building-house-tier3-mediterranean",
        "building-house-middle-eastern", "building-house-tier2-middle-eastern", "building-house-tier3-middle-eastern",
        "building-town-center-east-asian", "building-town-center-mediterranean", "building-town-center-middle-eastern"
    ]).union(houseAgeLooks).union(figureStems).union(goodsIcons)

    /// One icon per good (`good-tea-leaves`), drawn as SVG.
    static let goodsIcons: [String] = Good.allCases.map { "good-\($0.rawValue)" }

    /// The age looks of the three house tiers in every culture (`building-house-tier2-modern-east-asian`).
    static let houseAgeLooks: [String] = ["antiquity", "renaissance", "industrial", "modern"].flatMap { age in
        ["", "-east-asian", "-mediterranean", "-middle-eastern"].flatMap { culture in
            ["building-house", "building-house-tier2", "building-house-tier3"].map { "\($0)-\(age)\(culture)" }
        }
    }

    /// One stem per resident look, carrier load or animal action and facing (`walker-woman-se`,
    /// `carrier-logs-nw`, `animal-sheep-graze-sw`).
    static let figureStems: Set<String> = Set(SpriteAnimation.AnimationKey.figures.map {
        stem(of: SpriteAnimation.assetName(for: $0, frame: 0))
    })

    public static func mode(for spriteName: String, kitRendered: Set<String> = kitRenderedStems) -> SKTextureFilteringMode {
        if spriteName.hasPrefix("overlay-") {
            return .nearest
        }
        return kitRendered.contains(stem(of: spriteName)) ? .linear : .nearest
    }

    /// `building-sawmill-operational-2` → `building-sawmill`; `terrain-grass-beach-t3-1` and
    /// `terrain-grass-beach-t3-winter` → `terrain-grass-beach`; `terrain-grass-v2` → `terrain-grass`.
    /// A season ends a stem (`terrain-grass-autumn`) unless it follows a transition mask.
    public static func stem(of spriteName: String) -> String {
        var parts = spriteName.split(separator: "-").map(String.init)
        // A building's night lights (`building-bakery-lights`, `building-bakery-lights-2`) belong with the building.
        if parts.count > 3, parts[parts.count - 2] == "lights", parts[parts.count - 1].allSatisfy(\.isNumber) {
            parts.removeLast(2)
        } else if parts.count > 2, parts.last == "lights" {
            parts.removeLast()
        }
        if parts.count > 2, ["autumn", "winter"].contains(parts[parts.count - 1]), isMask(parts[parts.count - 2]) {
            parts.removeLast()
        }
        while let last = parts.last, parts.count > 2 {
            let isNumber = !last.isEmpty && last.allSatisfy(\.isNumber)
            let isTagged = (last.hasPrefix("v") || last.hasPrefix("t") || last.hasPrefix("c")) && last.count > 1 && last.dropFirst()
                .allSatisfy(\.isNumber)
            guard isNumber || isTagged else { break }
            parts.removeLast()
            if let state = parts.last, state == "constructing" || state == "operational" {
                parts.removeLast()
            }
        }
        return parts.joined(separator: "-")
    }

    /// A transition mask segment: `t` and digits.
    private static func isMask(_ part: String) -> Bool {
        part.count > 1 && part.hasPrefix("t") && part.dropFirst().allSatisfy(\.isNumber)
    }
}
