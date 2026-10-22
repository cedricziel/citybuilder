import CityCore
import SwiftUI

/// What Esc can close that `CityRootView` holds rather than the session.
/// Spec: `platform-shells` / Esc steps back on the Mac.
public struct StepBackState: Equatable, Sendable {
    /// A full-screen panel over the map, such as an overview. It closes
    /// before anything else.
    public var overviewOpen = false
    public var rail = BuildRailModel()
    /// The inspector's details, which hold the town market.
    public var inspectorExpanded = false

    public init(overviewOpen: Bool = false, rail: BuildRailModel = BuildRailModel(), inspectorExpanded: Bool = false) {
        self.overviewOpen = overviewOpen
        self.rail = rail
        self.inspectorExpanded = inspectorExpanded
    }
}

extension CityRootView {
    /// Closes the topmost open thing in the game window, one per press;
    /// with nothing open, pauses. Sheets take their own Esc.
    @MainActor
    static func stepBack(session: GameSession, state: inout StepBackState) {
        if session.deficitHint != nil {
            session.dismissDeficitHint()
        } else if state.overviewOpen {
            state.overviewOpen = false
        } else if session.pendingPlacement != nil {
            session.cancelPendingPlacement()
            session.clearTool()
        } else if state.rail.openDrawer != nil {
            state.rail.close()
        } else if session.selectedTool != .inspect {
            session.clearTool()
        } else if session.routeAuthoring != nil {
            session.cancelRouteAuthoring()
        } else if session.selectedTile != nil {
            if state.inspectorExpanded {
                state.inspectorExpanded = false
            } else {
                session.selectedTile = nil
            }
        } else {
            session.isPaused = true
        }
    }

    /// The root's step-back state. A new panel Esc should close adds its
    /// flag to `StepBackState` and maps it here.
    var stepBackState: Binding<StepBackState> {
        Binding(
            get: { StepBackState(rail: buildRail, inspectorExpanded: inspectorExpanded) },
            set: {
                buildRail = $0.rail
                inspectorExpanded = $0.inspectorExpanded
            }
        )
    }
}
