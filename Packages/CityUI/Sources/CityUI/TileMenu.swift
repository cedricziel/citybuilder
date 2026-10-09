import CityCore
import Foundation

/// A request to show the tile menu for `tile`. Spec: `rendering-2_5d` /
/// Tile context menu on long-press.
public struct TileMenuRequest: Equatable, Sendable {
    public let tile: TileCoordinate

    public init(tile: TileCoordinate) {
        self.tile = tile
    }
}

/// What the player picked from the tile menu.
public enum TileMenuChoice: Equatable, Sendable {
    case build(BuildingKind)
    case demolish
    case dismiss
}

/// One row of the tile menu.
public enum TileMenuItem: Hashable, Sendable {
    /// `reason` says why a disabled entry is disabled.
    case build(BuildingKind, enabled: Bool, reason: String?)
    case demolish
    case dismiss
}

extension TileMenuItem {
    /// Dialog button text: name plus cost, or why the entry is disabled.
    var title: String {
        switch self {
        case let .build(kind, enabled, reason):
            let name = BuildTool.place(kind).displayName
            if enabled {
                return "\(name) — $\(BuildingCatalog.spec(for: kind).cost)"
            }
            return reason.map { "\(name) — \($0)" } ?? name
        case .demolish: return "Demolish"
        case .dismiss: return "Cancel"
        }
    }
}

/// Rows of the tile menu for one tile. Follows the palette's rules: the
/// same kinds, obsolete ones hidden, locked ones shown but disabled.
/// Spec: `rendering-2_5d` / Tile context menu on long-press.
public struct TileMenuViewModel: Equatable, Sendable {
    public let tile: TileCoordinate
    public let items: [TileMenuItem]

    @MainActor
    public init(
        tile: TileCoordinate,
        world: World,
        money: Int64,
        isHidden: (BuildingKind) -> Bool = { _ in false }
    ) {
        self.tile = tile
        var items = BuildPaletteView.visibleKinds(isHidden: isHidden).map { kind in
            Self.buildItem(kind, at: tile, world: world, money: money)
        }
        // The player can't demolish a rival's building (design D3).
        if let id = world.occupiedTiles[tile], world.owner(of: id) == .player {
            items.append(.demolish)
        }
        items.append(.dismiss)
        self.items = items
    }

    private static func buildItem(_ kind: BuildingKind, at tile: TileCoordinate, world: World, money: Int64) -> TileMenuItem {
        if case let .rejected(reason) = world.canPlace(kind, at: tile) {
            return .build(kind, enabled: false, reason: PlacementRejectionText.message(for: reason, in: world))
        }
        let cost = BuildingCatalog.spec(for: kind).cost
        if money < cost {
            return .build(kind, enabled: false, reason: "Costs $\(cost)")
        }
        return .build(kind, enabled: true, reason: nil)
    }
}

public extension GameSession {
    func tileMenuViewModel(for tile: TileCoordinate) -> TileMenuViewModel {
        TileMenuViewModel(tile: tile, world: world, money: world.economy.balance, isHidden: isObsolete)
    }

    /// Long-press on a tile: select it for the inspector and ask for the
    /// menu. Ignored while a placement is pending, like taps.
    func handleLongPress(at tile: TileCoordinate) {
        guard pendingPlacement == nil, routeAuthoring == nil else { return }
        selectedTile = tile
        tileMenuRequest = TileMenuRequest(tile: tile)
    }

    /// Applies the player's pick. Buildings start a pending placement,
    /// road arms the road tool, demolish acts at once.
    func applyMenuChoice(_ choice: TileMenuChoice, at tile: TileCoordinate) {
        tileMenuRequest = nil
        switch choice {
        case .build(.road):
            selectedTool = .place(.road)
        case let .build(kind):
            beginPendingPlacement(kind: kind, at: tile)
        case .demolish:
            world.enqueue(.demolish(at: tile))
        case .dismiss:
            break
        }
    }
}
