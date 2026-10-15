import CityCore
import Foundation

/// Select, hold, the reticle tooltip and building placement. Spec:
/// `tv-remote-controls` / Select and hold on the map, Reticle tooltip,
/// Placement follows the reticle. Design D5.
extension RemoteInputMapper {
    /// The building whose tooltip shows beside the reticle: the inspect
    /// tool rested on it for the hover delay, with no placement pending.
    public func tooltipBuilding(at time: TimeInterval, session: GameSession) -> EntityID? {
        guard let id = Self.tooltipTarget(in: session),
              tooltip.currentTarget == Self.tooltipKey(id),
              tooltip.shouldShowTooltip(at: time)
        else { return nil }
        return id
    }

    /// Choosing a building in the rail or the tile menu moves focus to the
    /// map and starts its placement at the reticle; the road arms the
    /// road tool instead.
    public mutating func chooseBuilding(_ kind: BuildingKind, at _: TimeInterval, session: GameSession) -> [RemoteEffect] {
        session.tileMenuRequest = nil
        session.selectedTool = .place(kind)
        if kind != .road {
            session.beginPendingPlacement(kind: kind, at: session.reticleTile)
        }
        focus = .map
        return [.focusMap]
    }

    mutating func updateTooltip(at time: TimeInterval, session: GameSession) {
        tooltip.hoverChanged(to: Self.tooltipTarget(in: session).map(Self.tooltipKey), at: time)
    }

    /// A select held past the hold duration opens the tile menu, when the
    /// inspect tool is active, no placement is pending and the game is
    /// not in route mode. Otherwise the hold does nothing.
    mutating func holdSelectIfDue(at time: TimeInterval, session: GameSession) {
        guard let downAt = selectDownAt, !selectHoldFired, time - downAt >= Self.holdDuration else { return }
        selectHoldFired = true
        if session.selectedTool == .inspect, session.pendingPlacement == nil, session.routeAuthoring == nil {
            session.handleLongPress(at: session.reticleTile)
        }
    }

    mutating func selectReleased(at time: TimeInterval, session: GameSession) -> [RemoteEffect] {
        holdSelectIfDue(at: time, session: session)
        defer { selectDownAt = nil }
        guard selectDownAt != nil, !selectHoldFired else { return [] }
        return tap(session: session)
    }

    /// A short select acts as a tap on the reticle tile, confirms a
    /// pending placement, or focuses the callout of the building that is
    /// already selected.
    private mutating func tap(session: GameSession) -> [RemoteEffect] {
        let reticle = session.reticleTile
        if let pending = session.pendingPlacement {
            session.confirmPendingPlacement()
            if session.pendingPlacement == nil {
                session.beginPendingPlacement(kind: pending.kind, at: reticle)
            }
            return []
        }
        let reselects = session.routeAuthoring == nil && session.selectedTool == .inspect
            && session.selectedTile == reticle && session.world.occupiedTiles[reticle] != nil
        if reselects {
            focus = .hud
            return [.focusInspector]
        }
        session.handleTap(at: reticle)
        return []
    }

    private static func tooltipTarget(in session: GameSession) -> EntityID? {
        guard session.selectedTool == .inspect, session.pendingPlacement == nil, session.routeAuthoring == nil
        else { return nil }
        return session.world.occupiedTiles[session.reticleTile]
    }

    private static func tooltipKey(_ id: EntityID) -> String {
        String(id.raw)
    }
}
