import CityCore
import Foundation

/// What a building reaches, while placing and selecting. Spec:
/// `rendering-2_5d` / Areas of effect while placing and selecting, and
/// `platform-shells` / Count capsule over the ghost.
struct AreaOfEffectCache {
    struct Source: Equatable {
        let kind: BuildingKind
        let anchor: TileCoordinate
        let owner: Owner
        let placing: Bool
    }

    /// Nil for the area a blight or fever threatens, or under a red ghost.
    let source: Source?
    let hasGhost: Bool
    let tick: UInt64
    let area: AreaOfEffect?
}

public extension GameSession {
    /// What the ghost reaches, else, with the inspect tool, what the
    /// selected building reaches, else what a warned or running blight or
    /// fever threatens. Asked again at most once per tick and site, as a
    /// mine's sites take a placement check each.
    func areaOfEffect() -> AreaOfEffect? {
        let source = areaOfEffectSource()
        let hasGhost = ghostSite() != nil
        if let cache = areaOfEffectCache, cache.source == source, cache.hasGhost == hasGhost, cache.tick == world.tickCount {
            return cache.area
        }
        // A red ghost shows no area at all, not the threat behind it.
        let area: AreaOfEffect? = if let source {
            world.areaOfEffect(of: source.kind, at: source.anchor, owner: source.owner, placing: source.placing)
        } else {
            hasGhost ? nil : world.threatenedArea()
        }
        areaOfEffectCache = AreaOfEffectCache(source: source, hasGhost: hasGhost, tick: world.tickCount, area: area)
        return area
    }

    /// The count capsule over the ghost, while the ghost stands where its
    /// building could be placed and the building has something to count.
    var areaCountCapsule: AreaCountCapsuleModel? {
        guard let site = ghostSite(), isValidPlacement(site.kind, at: site.tile),
              let count = areaOfEffect()?.count,
              let text = AreaCountCapsuleModel.text(kind: site.kind, count: count)
        else { return nil }
        return AreaCountCapsuleModel(
            text: text, tone: AreaCountCapsuleModel.tone(kind: site.kind, count: count), kind: site.kind, anchor: site.tile
        )
    }

    /// The tile the inspector shows, while the inspect tool is armed.
    var inspectedTile: TileCoordinate? {
        selectedTool == .inspect ? selectedTile : nil
    }

    internal func areaOfEffectSource() -> AreaOfEffectCache.Source? {
        if let site = ghostSite() {
            // A red ghost shows no catchment, as it shows no count; a mine's sites still point the way.
            guard site.kind.catchmentRadius == nil || isValidPlacement(site.kind, at: site.tile) else { return nil }
            return AreaOfEffectCache.Source(kind: site.kind, anchor: site.tile, owner: .player, placing: true)
        }
        guard let tile = inspectedTile, let id = world.occupiedTiles[tile],
              let building = world.buildings[id]
        else { return nil }
        return AreaOfEffectCache.Source(kind: building.kind, anchor: building.anchor, owner: building.owner, placing: false)
    }
}

/// The capsule over the ghost: what its site reaches, and how worried
/// to look about it.
public struct AreaCountCapsuleModel: Equatable, Sendable {
    public enum Tone: Equatable, Sendable {
        /// Enough to work with: plain glass.
        case neutral
        /// Some, but the building will soon idle: amber.
        case low
        /// Nothing in reach: red. Placing stays allowed.
        case none
    }

    /// Below this many tiles in reach, a catchment reads low.
    public static let lowBelow = 5

    public let text: String
    public let tone: Tone
    public let kind: BuildingKind
    public let anchor: TileCoordinate

    /// "18 trees in reach", "12 open grass in reach" or "Mine site: 4 rock
    /// tiles"; nil for a kind that counts nothing.
    public static func text(kind: BuildingKind, count: Int) -> String? {
        if kind.catchmentRadius != nil {
            guard let noun = ToolStripText.inReachNoun(kind) else { return nil }
            if count == 0 { return "No \(noun) in reach" }
            return count == 1 && noun == "trees" ? "1 tree in reach" : "\(count) \(noun) in reach"
        }
        guard let terrain = BuildingCatalog.spec(for: kind).requiredTerrain?.terrain else { return nil }
        let ground = terrain == .mountain ? "rock" : terrain.rawValue
        return "\(kind.displayName) site: \(count) \(ground) tiles"
    }

    public static func tone(kind: BuildingKind, count: Int) -> Tone {
        guard kind.catchmentRadius != nil else { return .neutral }
        switch count {
        case 0: return .none
        case ..<lowBelow: return .low
        default: return .neutral
        }
    }
}
