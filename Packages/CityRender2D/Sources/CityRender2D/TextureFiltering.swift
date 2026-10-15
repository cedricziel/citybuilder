import SpriteKit

/// rendering-2_5d: World textures are @2x and linearly filtered (design D7).
///
/// Art-kit sprites are anti-aliased renders shipped with `@2x` twins, so they filter linearly.
/// Goods icons, status badges and the legacy pixel art keep `.nearest`. The legacy pixel art
/// becomes linear family by family, as each family PR adds its catalog entries to
/// `kitRenderedEntries`; once every family has migrated, every world texture is linear.
public enum TextureFiltering {
    /// Catalog entries (`Resources/Sprites.style/catalog/<id>.md`) whose sprites the art kit renders.
    /// Transition tiles belong to their upper terrain's entry (`terrain-grass-beach-t3` → `terrain-grass`).
    public static let kitRenderedEntries: Set<String> = []

    public static func mode(for spriteName: String, kitRendered: Set<String> = kitRenderedEntries) -> SKTextureFilteringMode {
        if spriteName.hasPrefix("good-") || spriteName.hasPrefix("overlay-") {
            return .nearest
        }
        return isKitRendered(spriteName, kitRendered: kitRendered) ? .linear : .nearest
    }

    /// Longest `-`-separated prefix match against the entries (`building-house-tier2` → `building-house`).
    static func isKitRendered(_ spriteName: String, kitRendered: Set<String>) -> Bool {
        var candidate = spriteName
        while true {
            if kitRendered.contains(candidate) { return true }
            guard let dash = candidate.lastIndex(of: "-") else { return false }
            candidate = String(candidate[..<dash])
        }
    }
}
