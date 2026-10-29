import CityCore
import CityRender2D
import Foundation

/// The kinds the player may place. World-gen seeds the town center for
/// free and fire leaves ruins, so neither is offered, and held kinds wait
/// for their mechanics.
public enum BuildPalette {
    /// Drawn, but not offered yet: the granary waits for "drawn last"
    /// (`add-event-counterplay` task 5.2), without which it is only a
    /// smaller warehouse. Empty this set when 5.2 lands.
    public static let held: Set<BuildingKind> = [.granary]

    public static let kinds = BuildingKind.allCases.filter {
        $0 != .townCenter && $0 != .ruins && !held.contains($0)
    }

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
        kind.category.flatMap(BuildCategory.init(rawValue:))
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

    @MainActor
    public mutating func toggle(_ category: BuildCategory) {
        openDrawer = openDrawer == category ? nil : category
        UISounds.play(openDrawer == nil ? .close : .open)
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
