import CityCore
import Foundation

/// Player-facing text for a rejected placement. Spec: `platform-shells`
/// / Placement rejection feedback.
public enum PlacementRejectionText {
    public static func message(for rejection: PlacementRejection) -> String {
        switch rejection {
        case .outOfBounds: "Outside the map"
        case .terrainNotBuildable: "Can't build on water"
        case .tileOccupied: "Tile occupied"
        case .shoreRequiresLandTile: "Needs a land tile"
        case .shoreRequiresWaterTile: "Must touch water"
        case let .needsTerrain(terrain): "Needs \(terrain.rawValue) ground"
        case let .locked(tech): "Needs \(tech.displayName) research"
        case let .obsolete(tech): "Replaced by \(tech.displayName)"
        case let .wrongCulture(culture): "Only \(culture.displayName) towns build this"
        case let .alreadyBuilt(kind): "Only one \(BuildTool.place(kind).displayName.lowercased()) per city"
        case .foreignIsland: "Another town's island"
        case let .insufficientMaterials(shortfall):
            "Needs " + Good.allCases.compactMap { good in
                shortfall[good].map { "\($0) more \(GoodsCatalog.spec(for: good).displayName.lowercased())" }
            }.joined(separator: ", ")
        }
    }
}
