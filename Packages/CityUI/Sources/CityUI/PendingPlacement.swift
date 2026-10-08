import CityCore
import Foundation

/// The four iso-grid axes the placement HUD nudges along. CityUI mirrors
/// CityRender2D's `IsoDirection` rather than importing it, so the UI
/// package keeps no dependency on the renderer (see
/// `SnapshotRendererRegistry`). Spec: `rendering-2_5d` / Iso direction
/// enumeration, Placement HUD.
public enum NudgeDirection: Hashable, Sendable, CaseIterable {
    case ne, se, sw, nw

    /// Tile-grid step for one nudge; same table as `IsoDirection`.
    public var tileOffset: (dx: Int, dy: Int) {
        switch self {
        case .ne: (dx: 0, dy: -1)
        case .se: (dx: 1, dy: 0)
        case .sw: (dx: 0, dy: 1)
        case .nw: (dx: -1, dy: 0)
        }
    }
}

/// A building the player is still positioning. Session-local: it is
/// never saved and never reaches the world's command queue until the
/// player confirms. Spec: `rendering-2_5d` / Placement-confirmation intents.
public struct PendingPlacement: Equatable, Sendable {
    public let kind: BuildingKind
    public var anchor: TileCoordinate
    /// Tile the placement started on.
    public let origin: TileCoordinate

    public init(kind: BuildingKind, anchor: TileCoordinate, origin: TileCoordinate) {
        self.kind = kind
        self.anchor = anchor
        self.origin = origin
    }
}

extension GameSession {
    /// Buildings other than roads wait for a confirmation on iOS; roads
    /// and demolition keep painting tile by tile.
    func needsConfirmation(_ kind: BuildingKind) -> Bool {
        confirmsBuildingPlacement && kind != .road
    }
}

public extension GameSession {
    func beginPendingPlacement(kind: BuildingKind, at tile: TileCoordinate) {
        pendingPlacement = PendingPlacement(kind: kind, anchor: tile, origin: tile)
    }

    /// Moves the anchor one tile along `direction`; a step off the map
    /// does nothing.
    func nudgePendingPlacement(_ direction: NudgeDirection) {
        guard var pending = pendingPlacement else { return }
        let offset = direction.tileOffset
        let next = TileCoordinate(x: pending.anchor.x + offset.dx, y: pending.anchor.y + offset.dy)
        guard world.contains(next) else { return }
        pending.anchor = next
        pendingPlacement = pending
    }

    /// Enqueues the placement and clears the pending state. A placement
    /// the world would reject stays pending, with the reason on the HUD,
    /// so the player can nudge it somewhere valid.
    func confirmPendingPlacement() {
        guard let pending = pendingPlacement else { return }
        if case let .rejected(reason) = world.canPlace(pending.kind, at: pending.anchor) {
            hud.showRejection(reason, now: Date())
            return
        }
        world.enqueue(.place(pending.kind, at: pending.anchor))
        pendingPlacement = nil
    }

    func cancelPendingPlacement() {
        pendingPlacement = nil
    }
}
