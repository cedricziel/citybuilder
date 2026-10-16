import SpriteKit

/// rendering-2_5d: World textures are @2x and linearly filtered (design D7).
///
/// Art-kit sprites are anti-aliased renders shipped with `@2x` twins, so they filter linearly.
/// Goods icons, status badges and the legacy pixel art keep `.nearest`; linear filtering would blur
/// pixel art. Each family PR adds its sprite stems as it migrates, and once every family has
/// migrated, every world texture is linear.
public enum TextureFiltering {
    /// Sprite stems the art kit renders: one per building look, terrain kind or transition pair, the
    /// way the migrated briefs' Sheet lists name them. A test keeps this set equal to the catalog.
    /// States, frames, variants and transition masks are stripped before the lookup, so
    /// `building-house-constructing-1` matches `building-house`. The match is exact:
    /// `building-house-mediterranean` is its own (legacy) brief.
    public static let kitRenderedStems: Set<String> = [
        "building-house", "building-house-tier2", "building-house-tier3", "building-town-center",
        "terrain-grass", "terrain-grass-autumn", "terrain-grass-winter", "terrain-beach", "terrain-water",
        "terrain-forest", "terrain-forest-autumn", "terrain-forest-winter", "terrain-mountain",
        "terrain-forest-single", "terrain-forest-single-autumn", "terrain-forest-single-winter",
        "terrain-forest-sparse", "terrain-forest-sparse-autumn", "terrain-forest-sparse-winter",
        "terrain-forest-medium", "terrain-forest-medium-autumn", "terrain-forest-medium-winter",
        "terrain-forest-dense", "terrain-forest-dense-autumn", "terrain-forest-dense-winter",
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
        "ship-n", "ship-ne", "ship-e", "ship-se", "ship-s", "ship-sw", "ship-w", "ship-nw"
    ]

    public static func mode(for spriteName: String, kitRendered: Set<String> = kitRenderedStems) -> SKTextureFilteringMode {
        if spriteName.hasPrefix("good-") || spriteName.hasPrefix("overlay-") {
            return .nearest
        }
        return kitRendered.contains(stem(of: spriteName)) ? .linear : .nearest
    }

    /// `building-sawmill-operational-2` → `building-sawmill`; `terrain-grass-beach-t3-1` and
    /// `terrain-grass-beach-t3-winter` → `terrain-grass-beach`; `terrain-mountain-v2` → `terrain-mountain`.
    /// A season ends a stem (`terrain-grass-autumn`) unless it follows a transition mask.
    public static func stem(of spriteName: String) -> String {
        var parts = spriteName.split(separator: "-").map(String.init)
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
