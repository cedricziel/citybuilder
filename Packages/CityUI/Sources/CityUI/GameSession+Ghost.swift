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
        guard case .allowed = world.canPlace(kind, at: tile) else { return false }
        return world.economy.balance >= BuildingCatalog.spec(for: kind).cost
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
