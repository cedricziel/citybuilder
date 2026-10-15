import CityCore
import SwiftUI

/// Spec: `platform-shells` / Esc steps back on the Mac.
extension CityRootView {
    /// Closes the topmost open thing in the game window, one per press;
    /// with nothing open, pauses. Sheets take their own Esc. A full-screen
    /// panel drawn over the map, such as an overview, goes first in this chain.
    @MainActor
    static func stepBack(session: GameSession, rail: Binding<BuildRailModel>, inspectorExpanded: Binding<Bool>) {
        if session.pendingPlacement != nil {
            session.cancelPendingPlacement()
            session.clearTool()
        } else if rail.wrappedValue.openDrawer != nil {
            rail.wrappedValue.close()
        } else if session.selectedTool != .inspect {
            session.clearTool()
        } else if session.routeAuthoring != nil {
            session.cancelRouteAuthoring()
        } else if session.selectedTile != nil {
            if inspectorExpanded.wrappedValue {
                inspectorExpanded.wrappedValue = false
            } else {
                session.selectedTile = nil
            }
        } else {
            session.isPaused = true
        }
    }
}
