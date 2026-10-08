import CityCore
import Foundation

/// The tool currently armed for tile interactions. Cycles via taps on
/// the palette buttons (tap once to arm, tap the same button to disarm
/// back to .inspect).
public enum BuildTool: Hashable, Sendable {
    case inspect
    case place(BuildingKind)
    case demolish

    public var displayName: String {
        switch self {
        case .inspect: return "Inspect"
        case .demolish: return "Demolish"
        case let .place(kind):
            switch kind {
            case .house: return "House"
            case .warehouse: return "Warehouse"
            case .road: return "Road"
            case .lumberjackHut: return "Lumberjack"
            case .farm: return "Farm"
            case .bakery: return "Bakery"
            case .grainFarm: return "Grain Farm"
            case .windmill: return "Windmill"
            case .quernHouse: return "Quern House"
            case .mine: return "Mine"
            case .charcoalBurner: return "Charcoal"
            case .smelter: return "Smelter"
            case .toolsmith: return "Toolsmith"
            case .library: return "Library"
            case .sawmill: return "Sawmill"
            case .townCenter: return "Town Ctr."
            case .port: return "Port"
            case .shipyard: return "Shipyard"
            case .hopGarden: return "Hop Garden"
            case .brewery: return "Brewery"
            case .vineyard: return "Vineyard"
            case .winery: return "Winery"
            case .teaGarden: return "Tea Garden"
            case .teaHouse: return "Tea House"
            case .coffeeGrove: return "Coffee Grove"
            case .roastery: return "Roastery"
            case .monument: return "Monument"
            case .guildHall: return "Guild Hall"
            case .gallery: return "Gallery"
            case .steamEngine: return "Steam Engine"
            case .powerPlant: return "Power Plant"
            case .meadHall: return "Mead Hall"
            case .forum: return "Forum"
            case .templeGarden: return "Temple Garden"
            case .caravanserai: return "Caravanserai"
            }
        }
    }
}
