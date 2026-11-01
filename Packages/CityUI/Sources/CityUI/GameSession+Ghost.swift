import CityCore
import Foundation

extension GameSession {
    /// Ghost preview state derived from the armed tool + hovered tile.
    /// `valid` runs the same canPlace check the simulation will use at
    /// the tick boundary, so the green / red tint matches reality.
    /// A pending placement overrides the hover.
    public func ghostState() -> GhostPreview? {
        ghostSite().map { ghostPreview(kind: $0.kind, tile: $0.tile) }
    }

    /// The building and tile the ghost shows: the pending placement, else
    /// the armed building at the hovered tile.
    func ghostSite() -> (kind: BuildingKind, tile: TileCoordinate)? {
        if let pending = pendingPlacement { return (pending.kind, pending.anchor) }
        guard let tile = hoveredTile, case let .place(kind) = selectedTool else { return nil }
        return (kind, tile)
    }

    private func ghostPreview(kind: BuildingKind, tile: TileCoordinate) -> GhostPreview {
        GhostPreview(
            kind: kind, tile: tile, valid: isValidPlacement(kind, at: tile),
            costBreakdown: costBreakdown(for: kind, anchor: tile)
        )
    }

    /// Whether the player may place `kind` at `tile` and can pay for it,
    /// the ghost's green tint.
    func isValidPlacement(_ kind: BuildingKind, at tile: TileCoordinate) -> Bool {
        placementRefusal(kind, at: tile) == nil
    }

    /// Why the world would turn down `kind` at `tile` right now, nil when
    /// it would build it. Covers the money the simulation charges too.
    func placementRefusal(_ kind: BuildingKind, at tile: TileCoordinate) -> PlacementRefusal? {
        if case let .rejected(reason) = world.canPlace(kind, at: tile) { return .rejected(reason) }
        return world.economy.balance >= BuildingCatalog.spec(for: kind).cost ? nil : .noMoney
    }

    /// Shows why `kind` can't go on `tile` and returns true, or returns
    /// false when it can.
    func refusesPlacement(_ kind: BuildingKind, at tile: TileCoordinate) -> Bool {
        guard let refusal = placementRefusal(kind, at: tile) else { return false }
        hud.showRejection(refusal.message(in: world), now: Date())
        UISounds.play(.reject)
        return true
    }

    func costBreakdown(
        for kind: BuildingKind,
        anchor: TileCoordinate
    ) -> [Good: GhostCost]? {
        let spec = BuildingCatalog.spec(for: kind)
        guard !spec.materialCost.isEmpty else { return nil }
        let tileToIsland = world.tileToIslandMap()
        let available = world.islandStockpile(at: anchor, tileToIsland: tileToIsland)
        let islandID = tileToIsland[anchor]
        var breakdown: [Good: GhostCost] = [:]
        for (good, need) in spec.materialCost {
            let have = available[good] ?? 0
            let status = statusFor(
                need: need, have: have,
                good: good, islandID: islandID,
                tileToIsland: tileToIsland
            )
            breakdown[good] = GhostCost(need: need, have: have, status: status)
        }
        return breakdown
    }

    private func statusFor(
        need: Int,
        have: Int,
        good: Good,
        islandID: IslandID?,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> CostStatus {
        if have >= need { return .ok }
        guard let islandID else { return .blocked }
        let supplied = world.producesGood(
            onIsland: islandID, good: good, tileToIsland: tileToIsland
        )
        return supplied ? .queueable : .blocked
    }

    /// A placement the world would turn down: one of its rules, or a
    /// price above the balance.
    enum PlacementRefusal: Equatable {
        case rejected(PlacementRejection)
        case noMoney

        func message(in world: World) -> String {
            switch self {
            case let .rejected(reason): PlacementRejectionText.message(for: reason, in: world)
            case .noMoney: GameText.string("placement.noMoney")
            }
        }
    }

    public struct GhostPreview: Equatable, Sendable {
        public let kind: BuildingKind
        public let tile: TileCoordinate
        public let valid: Bool
        /// Per-good `(need, have)` pair for the armed building on the
        /// hovered island. Nil when the building is free of materials
        /// (road, town center) — the cost row hides entirely. The view
        /// renders a chip per entry; goods where `have < need` paint
        /// red.
        public let costBreakdown: [Good: GhostCost]?

        public init(
            kind: BuildingKind,
            tile: TileCoordinate,
            valid: Bool,
            costBreakdown: [Good: GhostCost]? = nil
        ) {
            self.kind = kind
            self.tile = tile
            self.valid = valid
            self.costBreakdown = costBreakdown
        }

        /// View-helper: `isShort(.wood, in: breakdown)` returns true
        /// when the chip should render in the destructive style.
        public static func isShort(_ good: Good, in breakdown: [Good: GhostCost]) -> Bool {
            (breakdown[good]?.isShort) ?? false
        }
    }
}
