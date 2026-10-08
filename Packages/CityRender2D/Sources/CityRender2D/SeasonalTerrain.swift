import CityCore
import SpriteKit

/// Autumn and winter looks for vegetation. Spec: `rendering-2_5d` /
/// Terrain shows the season (design D7).
extension IsoWorldScene {
    static let seasonalTerrain: Set<TerrainType> = [.grass, .forest]

    /// `terrain-<kind>-<season>` for seasonal kinds in autumn and winter.
    static func seasonalTerrainName(kind: TerrainType, season: Season) -> String? {
        guard seasonalTerrain.contains(kind) else { return nil }
        switch season {
        case .spring, .summer: return nil
        case .autumn: return "terrain-\(kind.rawValue)-autumn"
        case .winter: return "terrain-\(kind.rawValue)-winter"
        }
    }

    private static var seasonalActionCache: [String: SKAction] = [:]

    /// The seasonal sprite for a terrain tile, with its looping frames
    /// when the kind animates, or nil to use the regular sprite.
    func seasonalTerrainNode(kind: TerrainType) -> SKSpriteNode? {
        guard let name = Self.seasonalTerrainName(kind: kind, season: appliedSeason),
              hasSprite(name)
        else { return nil }
        let node = SKSpriteNode(texture: SpriteAtlas.textureOrPlaceholder(named: name))
        node.userData = [Self.textureNameKey: name]
        if let action = Self.seasonalLoop(name: name, kind: kind) {
            node.run(action, withKey: "anim")
        }
        return node
    }

    private static func seasonalLoop(name: String, kind: TerrainType) -> SKAction? {
        if let hit = seasonalActionCache[name] { return hit }
        guard let entry = SpriteAnimation.entry(for: .terrain(kind)), entry.loop == .forever else { return nil }
        let frames = (0 ..< entry.frameCount).compactMap { SpriteAtlas.texture(named: "\(name)-\($0)") }
        guard frames.count == entry.frameCount, frames.count > 1 else { return nil }
        let action = SKAction.repeatForever(.animate(with: frames, timePerFrame: entry.timePerFrame))
        seasonalActionCache[name] = action
        return action
    }
}
