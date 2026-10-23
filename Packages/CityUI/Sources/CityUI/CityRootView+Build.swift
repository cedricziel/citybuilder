import CityCore
import SwiftUI

/// The map-first HUD layer: status pill and menus on top, build rail or
/// dock, tool strip with the rejection banner, and the inspector callout.
/// Split out of `CityRootView` to keep the main file under SwiftLint's
/// 500-line ceiling. Spec: `platform-shells` / Adaptive HUD per idiom.
extension CityRootView {
    func hudLayer(layout: HUDLayout, hudWidth: CGFloat, worldViewSize: CGSize) -> some View {
        let railInset = layout.railInset
        let firstStepsGuide = session.firstStepsGuide
        return ZStack {
            VStack(spacing: 8) {
                // The section includes the inset, so its frame spans the
                // rail too and Up from the rail reaches the top bar.
                topBar(layout: layout)
                    .padding(.leading, railInset)
                    .tvFocusSection()
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 8) {
                        StocksTrayView(
                            hud: session.hud,
                            layout: layout,
                            maxWidth: MinimapLayout.trayColumnWidth(
                                hudWidth: hudWidth, layout: layout, showsMinimap: showsCornerMinimap
                            )
                        )
                        SessionBannerView(
                            banner: session.banner,
                            onResume: session.deficitHint == nil || session.isGameOver ? nil : { session.dismissDeficitHint() }
                        )
                        .padding(.top, 4)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .panelAnimation(value: session.banner)
                    VStack(alignment: .trailing, spacing: 8) {
                        if MinimapLayout.corner(for: layout) == .topTrailing {
                            minimap(layout: layout, worldViewSize: worldViewSize)
                        }
                        if let guide = firstStepsGuide {
                            FirstStepsCardView(guide: guide, layout: layout) { session.hideFirstSteps() }
                                .panelTransition(.fade)
                        }
                    }
                    .panelAnimation(value: firstStepsGuide == nil)
                }
                .padding(.leading, railInset)
            }
            if let authoring = session.routeAuthoring {
                VStack {
                    Spacer()
                    RouteAuthoringOverlay(session: session, authoring: authoring)
                        .tvFocusSection()
                }
                .panelTransition(.slide(.bottom))
            } else {
                buildControls(layout: layout, railInset: railInset, worldViewSize: worldViewSize)
                    .panelAnimation(value: buildRail.openDrawer)
            }
        }
        .panelAnimation(value: session.routeAuthoring != nil)
    }

    @ViewBuilder
    private func topBar(layout: HUDLayout) -> some View {
        let pill = StatusPillView(hud: session.hud, session: session, layout: layout) { session.togglePause() }
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
                ToolStripView(session: session, idiom: layout.idiom)
            }
        }
    }

    @ViewBuilder
    private func buildControls(layout: HUDLayout, railInset: CGFloat, worldViewSize: CGSize) -> some View {
        switch layout.placement {
        case .leftRail:
            HStack(alignment: .center, spacing: 8) {
                BuildRailView(session: session, rail: $buildRail, layout: layout)
                BuildDrawerView(session: session, rail: $buildRail, layout: layout)
                Spacer(minLength: 0)
            }
            .tvFocusSection()
            .frame(maxHeight: .infinity)
            VStack {
                Spacer()
                // The minimap shares the bottom row, so the tool strip and
                // the rejection banner stay left of it.
                HStack(alignment: .bottom, spacing: 8) {
                    bottomStack(layout: layout).frame(maxWidth: .infinity)
                    minimap(layout: layout, worldViewSize: worldViewSize)
                }
            }
            .padding(.leading, railInset)
        case .bottomDock:
            VStack(spacing: 8) {
                Spacer()
                BuildDrawerView(session: session, rail: $buildRail, layout: layout)
                bottomStack(layout: layout)
                BuildRailView(session: session, rail: $buildRail, layout: layout)
                    .tvFocusSection()
            }
        }
    }

    /// Whether the corner minimap shows: never on Apple TV, which has the
    /// overview instead. Spec: `platform-shells` / Minimap toggle.
    var showsCornerMinimap: Bool {
        #if os(tvOS)
        false
        #else
        showsMinimap
        #endif
    }

    @ViewBuilder
    private func minimap(layout: HUDLayout, worldViewSize: CGSize) -> some View {
        #if !os(tvOS)
        if showsCornerMinimap {
            MinimapCard(session: session, layout: layout, worldViewSize: worldViewSize)
                .panelTransition(.fade)
        }
        #endif
    }

    /// The inspector callout for the selected building, while inspecting.
    /// It rises in, and glides when another tile is inspected.
    var inspectorCallout: some View {
        ZStack { inspectorCalloutContent }
            .panelAnimation(value: session.selectedTool == .inspect ? session.selectedTile : nil)
    }

    @ViewBuilder
    private var inspectorCalloutContent: some View {
        if session.routeAuthoring == nil, session.selectedTool == .inspect, let tile = session.selectedTile {
            let inspector = session.inspector
            if !inspector.bullets.isEmpty {
                GeometryReader { proxy in
                    InspectorCalloutView(
                        session: session,
                        viewModel: inspector,
                        tile: tile,
                        layout: HUDMetrics.layout(for: proxy.size),
                        showsMinimap: showsCornerMinimap,
                        isExpanded: $inspectorExpanded
                    ) {
                        inspectorActionsButton
                    }
                    .tvFocusSection()
                }
                .panelTransition(.rise)
            }
        }
    }
}
