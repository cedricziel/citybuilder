import CityCore
import Foundation

/// The kinds the player may place. World-gen seeds the town center for
/// free, so it is not offered.
public enum BuildPalette {
    public static let kinds = BuildingKind.allCases.filter { $0 != .townCenter }

    /// Palette kinds minus hidden ones (obsolete or other-culture buildings).
    /// Spec: `platform-shells` / Palette hides obsolete buildings.
    public static func visibleKinds(isHidden: (BuildingKind) -> Bool) -> [BuildingKind] {
        kinds.filter { !isHidden($0) }
    }
}

/// The build rail's drawers. Spec: `platform-shells` / Build categories,
/// rail and drawers.
public enum BuildCategory: String, CaseIterable, Hashable, Sendable {
    case town
    case gather
    case craft

    public var label: String {
        switch self {
        case .town: "Town"
        case .gather: "Gather"
        case .craft: "Craft"
        }
    }

    public var hotkey: Character {
        switch self {
        case .town: "1"
        case .gather: "2"
        case .craft: "3"
        }
    }

    /// The kind whose sprite stands for the category on the rail.
    public var representative: BuildingKind {
        switch self {
        case .town: .house
        case .gather: .lumberjackHut
        case .craft: .sawmill
        }
    }

    /// Nil for the road, which has its own rail item, and the town center,
    /// which is never offered.
    public static func of(_ kind: BuildingKind) -> BuildCategory? {
        switch kind {
        case .road, .townCenter:
            nil
        case .lumberjackHut, .farm, .grainFarm, .mine, .hopGarden, .vineyard, .teaGarden, .coffeeGrove:
            .gather
        case .sawmill, .windmill, .quernHouse, .bakery, .charcoalBurner, .smelter, .toolsmith,
             .brewery, .winery, .roastery, .steamEngine, .powerPlant:
            .craft
        case .house, .warehouse, .library, .port, .shipyard, .teaHouse, .monument, .guildHall,
             .gallery, .meadHall, .forum, .templeGarden, .caravanserai:
            .town
        }
    }

    public static func kinds(in category: BuildCategory, isHidden: (BuildingKind) -> Bool) -> [BuildingKind] {
        BuildPalette.visibleKinds(isHidden: isHidden).filter { of($0) == category }
    }
}

/// Which drawer is open. Picking a kind arms it and closes the drawer.
public struct BuildRailModel: Equatable, Sendable {
    public static let roadHotkey: Character = "r"
    public static let demolishHotkey: Character = "x"

    public private(set) var openDrawer: BuildCategory?

    public init() {}

    public mutating func toggle(_ category: BuildCategory) {
        openDrawer = openDrawer == category ? nil : category
    }

    public mutating func close() {
        openDrawer = nil
    }

    @MainActor
    public mutating func arm(_ kind: BuildingKind, in session: GameSession) {
        guard !session.isLocked(kind) else { return }
        if session.selectedTool != .place(kind) {
            session.selectTool(.place(kind))
        }
        openDrawer = nil
    }

    /// The open drawer, or with none open the armed kind's category.
    public func highlightedCategory(armed: BuildTool) -> BuildCategory? {
        if let openDrawer { return openDrawer }
        if case let .place(kind) = armed { return BuildCategory.of(kind) }
        return nil
    }
}
