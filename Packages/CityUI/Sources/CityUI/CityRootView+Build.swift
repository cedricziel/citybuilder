import CityCore
import SwiftUI

/// The map-first HUD layer: status pill and menus on top, build rail or
/// dock, tool strip, and the inspector callout. Split out of
/// `CityRootView` to keep the main file under SwiftLint's 500-line
/// ceiling. Spec: `platform-shells` / Adaptive HUD per idiom.
extension CityRootView {
    func hudLayer(dock: HUDDock) -> some View {
        let railInset = dock == .leftRail ? HUDMetrics.railWidth + 8 : 0
        return ZStack {
            VStack(spacing: 8) {
                topBar(dock: dock)
                StocksTrayView(hud: session.hud)
                PlacementRejectionBanner(hud: session.hud)
                SessionBannerView(banner: session.banner)
                Spacer(minLength: 0)
            }
            .padding(.leading, railInset)
            if let authoring = session.routeAuthoring {
                VStack {
                    Spacer()
                    RouteAuthoringOverlay(session: session, authoring: authoring)
                }
            } else {
                buildControls(dock: dock, railInset: railInset)
            }
        }
    }

    @ViewBuilder
    private func topBar(dock: HUDDock) -> some View {
        let pill = StatusPillView(hud: session.hud, session: session) { session.isPaused.toggle() }
            .fixedSize()
        if HUDMetrics.isPhone, dock == .bottomDock {
            VStack(alignment: .trailing, spacing: 8) {
                pill.frame(maxWidth: .infinity)
                menuButtons
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                pill
                menuButtons.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func buildControls(dock: HUDDock, railInset: CGFloat) -> some View {
        let hidesStrip = buildRail.openDrawer != nil || (HUDMetrics.isPhone && session.pendingPlacement != nil)
        switch dock {
        case .leftRail:
            HStack(alignment: .center, spacing: 8) {
                BuildRailView(session: session, rail: $buildRail, isVertical: true)
                BuildDrawerView(session: session, rail: $buildRail, isPortrait: false)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
            if !hidesStrip {
                VStack {
                    Spacer()
                    ToolStripView(session: session)
                }
                .padding(.leading, railInset)
            }
        case .bottomDock:
            VStack(spacing: 8) {
                Spacer()
                BuildDrawerView(session: session, rail: $buildRail, isPortrait: true)
                if !hidesStrip {
                    ToolStripView(session: session)
                }
                BuildRailView(session: session, rail: $buildRail, isVertical: false)
            }
        }
    }

    /// The inspector callout for the selected building, while inspecting.
    @ViewBuilder
    var inspectorCallout: some View {
        if session.routeAuthoring == nil, session.selectedTool == .inspect, let tile = session.selectedTile {
            let inspector = session.inspector
            if !inspector.bullets.isEmpty {
                GeometryReader { proxy in
                    InspectorCalloutView(
                        session: session,
                        viewModel: inspector,
                        tile: tile,
                        placement: HUDDock.placement(for: proxy.size)
                    ) {
                        inspectorActionsButton
                    }
                }
            }
        }
    }
}
