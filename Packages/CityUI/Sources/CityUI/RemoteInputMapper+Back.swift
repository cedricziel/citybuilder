import CityCore
import Foundation

/// Where the remote's Back press lands.
public enum RemoteScreen: Hashable, Sendable {
    case title, game
}

/// How the reticle draws: each tool mode gets its own look. Design D6.
public enum ReticleStyle: Hashable, Sendable {
    case idle, painting, demolish
}

public extension GameSession {
    var reticleStyle: ReticleStyle {
        if selectedTool == .demolish { return .demolish }
        return isPaintingRoad ? .painting : .idle
    }
}

/// Road painting, demolish and the Back order. Spec: `tv-remote-controls`
/// / Road painting, Demolish acts on one building at a time, Back steps
/// out one level at a time. Design D6, D8.
extension RemoteInputMapper {
    /// The title screen leaves Back to the system, which returns to the
    /// Home screen as Apple's tvOS guidance requires.
    public nonisolated static func handlesBack(on screen: RemoteScreen) -> Bool {
        screen == .game
    }

    /// Select with the road tool toggles painting; turning it on paints
    /// the reticle tile.
    mutating func toggleRoadPainting(session: GameSession) {
        session.isPaintingRoad.toggle()
        if session.isPaintingRoad {
            session.handleTap(at: session.reticleTile)
        }
    }

    /// While painting, a click paints the tile it steps onto. Swipes never
    /// paint, and demolish never paints.
    func paintAfterClick(from previous: TileCoordinate, session: GameSession) {
        guard session.isPaintingRoad, session.reticleTile != previous else { return }
        session.handleTap(at: session.reticleTile)
    }

    /// Undoes the innermost state, one level per press: the pause menu,
    /// the tile menu, HUD focus, a pending placement, road painting, an
    /// armed tool, a route stop or route mode, the selection; on an idle
    /// map, Back opens the pause menu.
    mutating func back(session: GameSession) -> [RemoteEffect] {
        if session.isPaused {
            session.isPaused = false
        } else if session.tileMenuRequest != nil {
            session.tileMenuRequest = nil
        } else if focus == .hud {
            focus = .map
            return [.focusMap]
        } else if session.pendingPlacement != nil {
            session.cancelPendingPlacement()
            session.clearTool()
        } else if session.isPaintingRoad {
            session.isPaintingRoad = false
        } else if session.selectedTool != .inspect {
            session.clearTool()
        } else if let authoring = session.routeAuthoring {
            if authoring.inProgressWaypoints.isEmpty {
                session.cancelRouteAuthoring()
            } else {
                authoring.removeLastWaypoint()
            }
        } else if session.selectedTile != nil {
            session.selectedTile = nil
        } else {
            session.isPaused = true
        }
        return []
    }
}
