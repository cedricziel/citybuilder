import CityCore
import SpriteKit

/// Autumn and winter looks for vegetation, and per-tile variants. Spec: `rendering-2_5d` /
/// Terrain shows the season (design D7), Grass picks a variant per tile (terrain-v2, D2).
extension IsoWorldScene {
    static let seasonalTerrain: Set<TerrainType> = [.grass]

    /// `terrain-<kind>-<season>` for seasonal kinds in autumn and winter.
    static func seasonalTerrainName(kind: TerrainType, season: Season) -> String? {
        guard seasonalTerrain.contains(kind) else { return nil }
        switch season {
        case .spring, .summer: return nil
        case .autumn: return "terrain-\(kind.rawValue)-autumn"
        case .winter: return "terrain-\(kind.rawValue)-winter"
        }
    }

    private static var terrainActionCache: [String: SKAction] = [:]

    /// The sprite for a tile drawn from its own terrain: the season's look when the atlas has it,
    /// then the tile's variant of that look when the atlas has it (grass and rock come in variants).
    func terrainSpriteName(kind: TerrainType, coord: TileCoordinate) -> String {
        let count = SpriteAtlas.terrainVariantCounts[kind] ?? 1
        return terrainSpriteName(kind: kind, season: appliedSeason, variant: SpriteAtlas.variantIndex(coord: coord, count: count))
    }

    /// The sprite for `kind` in `season`, in `variant` where the kind has variants.
    func terrainSpriteName(kind: TerrainType, season: Season, variant index: Int) -> String {
        let seasonal = Self.seasonalTerrainName(kind: kind, season: season).flatMap { hasSprite($0) ? $0 : nil }
        let stem = seasonal ?? "terrain-\(kind.rawValue)"
        guard (SpriteAtlas.terrainVariantCounts[kind] ?? 1) > 1 else { return stem }
        let variant = SpriteAtlas.variantAssetName(stem: stem, variant: index)
        guard hasSprite(variant) else {
            missLog.logOnce(variant) // rendering-2_5d: Missing-sprite fallback in release
            return stem
        }
        return variant
    }

    /// A tile drawn from its own terrain, looping `<name>-<frame>` when its kind animates.
    func plainTerrainNode(kind: TerrainType, coord: TileCoordinate) -> SKSpriteNode {
        let name = terrainSpriteName(kind: kind, coord: coord)
        let node = SKSpriteNode(texture: textureOrPlaceholder(named: name))
        node.userData = [Self.textureNameKey: name]
        if let action = Self.terrainLoop(name: name, kind: kind) {
            node.run(action, withKey: "anim")
        }
        return node
    }

    private static func terrainLoop(name: String, kind: TerrainType) -> SKAction? {
        if let hit = terrainActionCache[name] { return hit }
        guard let entry = SpriteAnimation.entry(for: .terrain(kind)), entry.loop == .forever else { return nil }
        let frames = (0 ..< entry.frameCount).compactMap { SpriteAtlas.texture(named: "\(name)-\($0)") }
        guard frames.count == entry.frameCount, frames.count > 1 else { return nil }
        let action = SKAction.repeatForever(.animate(with: frames, timePerFrame: entry.timePerFrame))
        terrainActionCache[name] = action
        return action
    }
}
