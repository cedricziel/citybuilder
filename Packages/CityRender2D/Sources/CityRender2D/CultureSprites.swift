import CityCore
import SpriteKit

/// Culture-specific building looks. Spec: `rendering-2_5d` / Buildings
/// render in the world's culture.
extension IsoWorldScene {
    static let cultureVariantKinds: Set<BuildingKind> = [.house, .townCenter, .warehouse, .library]

    /// The culture variant's sprite name for a finished building, or nil
    /// when the culture has no variant for it. Northern European uses the
    /// shared names (design D3).
    static func cultureTextureName(kind: BuildingKind, houseTier: HouseTier, culture: Culture) -> String? {
        guard culture != .northernEuropean, cultureVariantKinds.contains(kind) else { return nil }
        if kind == .house, houseTier != .peasants {
            return "building-house-tier\(houseTier.rawValue)-\(culture.rawValue)"
        }
        return "building-\(kind.rawValue)-\(culture.rawValue)"
    }

    /// The culture variant's name and texture for a finished building,
    /// when the atlas has one.
    func cultureTexture(kind: BuildingKind, state: BuildingState, houseTier: HouseTier) -> (String, SKTexture)? {
        guard state != .constructing,
              let name = Self.cultureTextureName(kind: kind, houseTier: houseTier, culture: culture),
              hasSprite(name)
        else { return nil }
        return (name, SpriteAtlas.textureOrPlaceholder(named: name))
    }

    private static var cultureActionCache: [String: SKAction] = [:]

    /// Looping operational frames `<baseName>-operational-N`, or nil when
    /// the kind has no operational loop or a frame is missing.
    static func cultureOperationalAction(baseName: String, kind: BuildingKind) -> SKAction? {
        if let hit = cultureActionCache[baseName] { return hit }
        guard let entry = SpriteAnimation.entry(for: .buildingOperational(kind)), entry.loop == .forever else {
            return nil
        }
        let frames = (0 ..< entry.frameCount).compactMap { SpriteAtlas.texture(named: "\(baseName)-operational-\($0)") }
        guard frames.count == entry.frameCount, frames.count > 1 else { return nil }
        let action = SKAction.repeatForever(.animate(with: frames, timePerFrame: entry.timePerFrame))
        cultureActionCache[baseName] = action
        return action
    }
}
