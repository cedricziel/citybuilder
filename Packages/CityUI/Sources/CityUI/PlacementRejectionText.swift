import CityCore
import Foundation

/// Player-facing text for a rejected placement. Spec: `platform-shells`
/// / Placement rejection feedback.
public enum PlacementRejectionText {
    // swiftlint:disable:next cyclomatic_complexity
    public static func message(for rejection: PlacementRejection) -> String {
        switch rejection {
        case .outOfBounds: GameText.string("placement.outOfBounds")
        case .terrainNotBuildable: GameText.string("placement.water")
        case .tileOccupied: GameText.string("placement.occupied")
        case .shoreRequiresLandTile: GameText.string("placement.needsLand")
        case .shoreRequiresWaterTile: GameText.string("placement.needsWater")
        case let .needsTerrain(terrain): GameText.string("placement.needsTerrain", terrain.localizedName)
        case let .locked(tech): GameText.string("placement.locked", tech.displayName)
        case let .obsolete(tech): GameText.string("placement.obsolete", tech.displayName)
        case let .wrongCulture(culture): GameText.string("placement.wrongCulture", culture.displayName)
        case let .alreadyBuilt(kind): GameText.string("placement.alreadyBuilt", GameText.inSentence(BuildTool.place(kind).displayName))
        case .foreignIsland: GameText.string("placement.foreignIsland")
        case .closed: GameText.string("placement.closed")
        case let .insufficientMaterials(shortfall):
            GameText.string("placement.needsMore", Good.allCases.compactMap { good in
                shortfall[good].map { GameText.string("placement.more", $0, GameText.inSentence(good.displayName)) }
            }.joined(separator: ", "))
        }
    }

    /// Like `message(for:)`, naming the rival whose island it is.
    public static func message(for rejection: PlacementRejection, in world: World) -> String {
        if case let .foreignIsland(.rival(id)) = rejection, let name = world.rival(id)?.displayName {
            return GameText.string("placement.rivalIsland", name)
        }
        return message(for: rejection)
    }
}

extension TerrainType {
    /// The terrain's name inside a sentence.
    var localizedName: String {
        switch self {
        case .grass: GameText.string("terrain.grass")
        case .forest: GameText.string("terrain.forest")
        case .beach: GameText.string("terrain.beach")
        case .water: GameText.string("terrain.water")
        case .mountain: GameText.string("terrain.mountain")
        }
    }
}
