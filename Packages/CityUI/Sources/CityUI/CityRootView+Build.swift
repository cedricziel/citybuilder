import CityCore
import SwiftUI

/// The map-first HUD layer: status pill and menus on top, build rail or
/// dock, tool strip with the rejection banner, and the inspector callout.
/// Split out of `CityRootView` to keep the main file under SwiftLint's
/// 500-line ceiling. Spec: `platform-shells` / Adaptive HUD per idiom.
extension CityRootView {
    func hudLayer(layout: HUDLayout) -> some View {
        let railInset = layout.placement == .leftRail ? layout.railWidth + 8 : 0
        return ZStack {
            VStack(spacing: 8) {
                topBar(layout: layout)
                StocksTrayView(hud: session.hud, layout: layout)
                SessionBannerView(banner: session.banner)
                    .padding(.top, 4)
                Spacer(minLength: 0)
            }
            .padding(.leading, railInset)
            if let authoring = session.routeAuthoring {
                VStack {
                    Spacer()
                    RouteAuthoringOverlay(session: session, authoring: authoring)
                }
            } else {
                buildControls(layout: layout, railInset: railInset)
            }
        }
    }

    @ViewBuilder
    private func topBar(layout: HUDLayout) -> some View {
        let pill = StatusPillView(hud: session.hud, session: session, layout: layout) { session.isPaused.toggle() }
            .fixedSize()
        if layout.foldsMenus {
            HStack(alignment: .top, spacing: 8) {
                pill
                Spacer(minLength: 0)
                moreMenu
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                pill
                menuButtons.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    /// The rejection banner sits directly above the tool strip.
    private func bottomStack(layout: HUDLayout) -> some View {
        let hidesStrip = buildRail.openDrawer != nil || (layout.isPhone && session.pendingPlacement != nil)
        return VStack(spacing: 8) {
            PlacementRejectionBanner(hud: session.hud)
            if !hidesStrip {
                ToolStripView(session: session)
            }
        }
    }

    @ViewBuilder
    private func buildControls(layout: HUDLayout, railInset: CGFloat) -> some View {
        switch layout.placement {
        case .leftRail:
            HStack(alignment: .center, spacing: 8) {
                BuildRailView(session: session, rail: $buildRail, layout: layout)
                BuildDrawerView(session: session, rail: $buildRail, layout: layout)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
            VStack {
                Spacer()
                bottomStack(layout: layout)
            }
            .padding(.leading, railInset)
        case .bottomDock:
            VStack(spacing: 8) {
                Spacer()
                BuildDrawerView(session: session, rail: $buildRail, layout: layout)
                bottomStack(layout: layout)
                BuildRailView(session: session, rail: $buildRail, layout: layout)
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
                        layout: HUDMetrics.layout(for: proxy.size),
                        isExpanded: $inspectorExpanded
                    ) {
                        inspectorActionsButton
                    }
                }
            }
        }
    }
}
