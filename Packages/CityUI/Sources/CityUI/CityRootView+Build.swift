import CityCore
import SwiftUI

/// The map-first HUD layer: status pill and menus on top, build rail or
/// dock, tool strip with the rejection banner, and the inspector callout.
/// Split out of `CityRootView` to keep the main file under SwiftLint's
/// 500-line ceiling. Spec: `platform-shells` / Adaptive HUD per idiom.
extension CityRootView {
    func hudLayer(layout hudLayout: HUDLayout, hudWidth: CGFloat, worldViewSize: CGSize, insets: EdgeInsets) -> some View {
        // The open board takes the right column, so the first-steps card
        // shows as its capsule (`Order board layout`).
        let boardFrame = session.isOrdersPresented
            ? OrderBoardLayout.frame(
                in: worldViewSize, insets: insets, layout: hudLayout, showsMinimap: showsCornerMinimap,
                showsFirstSteps: session.firstStepsGuide != nil
            )
            : nil
        let layout = boardFrame == nil ? hudLayout : hudLayout.withFirstStepsCollapsed
        let railInset = layout.railInset
        let firstStepsGuide = session.firstStepsGuide
        let bannerFitsColumn = bannerFitsColumn(layout: layout, hudWidth: hudWidth)
        return ZStack {
            VStack(spacing: 8) {
                // The section includes the inset, so its frame spans the
                // rail too and Up from the rail reaches the top bar.
                topBar(layout: hudLayout)
                    .padding(.leading, railInset)
                    .tvFocusSection()
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 8) {
                        DateChipView(
                            hud: session.hud, layout: layout, hudWidth: hudWidth, showsFirstSteps: firstStepsGuide != nil
                        )
                        EventChipView(
                            chip: session.hud.eventChip, layout: layout, hudWidth: hudWidth,
                            showsFirstSteps: firstStepsGuide != nil
                        ) { session.replaySeasonalWarning() }
                        StocksTrayView(
                            hud: session.hud,
                            layout: layout,
                            maxWidth: MinimapLayout.trayColumnWidth(
                                hudWidth: hudWidth, layout: layout, showsMinimap: showsCornerMinimap,
                                showsFirstSteps: firstStepsGuide != nil
                            )
                        )
                        if bannerFitsColumn {
                            sessionBanner.padding(.top, 4)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    // The event chip is the column's one control: Left and Right reach it.
                    .tvFocusSection()
                    .panelAnimation(value: session.banner)
                    rightColumn(layout: layout, worldViewSize: worldViewSize, boardFrame: boardFrame)
                }
                .padding(.leading, railInset)
            }
            if !bannerFitsColumn {
                wideBanner(layout: layout)
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

    /// Whether the left column is wide enough for a session banner.
    private func bannerFitsColumn(layout: HUDLayout, hudWidth: CGFloat) -> Bool {
        SessionBannerLayout.fitsColumn(width: MinimapLayout.trayColumnWidth(
            hudWidth: hudWidth, layout: layout, showsMinimap: showsCornerMinimap, showsFirstSteps: session.firstStepsGuide != nil
        ))
    }

    /// The left column is the HUD less the rail and whatever takes the right
    /// column (the open first-steps card or a top-right minimap). Under
    /// `SessionBannerLayout.minWidth` it would squeeze a banner over the
    /// inspector, so the banner spans the HUD above the build controls
    /// instead, as on an iPhone SE with the first-steps card open.
    private func wideBanner(layout: HUDLayout) -> some View {
        VStack {
            Spacer()
            sessionBanner
                .padding(.bottom, SessionBannerLayout.bottomInset(layout: layout))
        }
        .panelAnimation(value: session.banner)
    }

    private var sessionBanner: some View {
        SessionBannerView(
            banner: session.banner,
            onResume: session.deficitHint == nil || session.isGameOver ? nil : { session.dismissDeficitHint() }
        )
    }

    /// The trailing column under the top bar: the minimap in the dock
    /// layout, the first-steps card and the order board.
    private func rightColumn(layout: HUDLayout, worldViewSize: CGSize, boardFrame: CGRect?) -> some View {
        let guide = session.firstStepsGuide
        return VStack(alignment: .trailing, spacing: 8) {
            if MinimapLayout.corner(for: layout) == .topTrailing {
                minimap(layout: layout, worldViewSize: worldViewSize)
            }
            if let guide {
                FirstStepsCardView(guide: guide, layout: layout) { session.hideFirstSteps() }
                    .panelTransition(.fade)
            }
            if let boardFrame {
                OrdersBoardColumn(session: session, frame: boardFrame, isTV: layout.idiom == .tv)
                    .panelTransition(.slide(.trailing))
            }
        }
        .tvFocusSection()
        .panelAnimation(value: guide == nil)
        .panelAnimation(value: boardFrame != nil)
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
            .hudChromeTypeSize()
        } else {
            HStack(alignment: .top, spacing: 8) {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                pill
                menuButtons(layout: layout).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .hudChromeTypeSize()
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
            // A short landscape screen has no room for a tall drawer beside the rail under the
            // status pill: the drawer starts below the top bar and shortens to what is left.
            let topBand = layout.isCompactHeight ? layout.controlHeight + 8 : 0
            GeometryReader { proxy in
                HStack(alignment: .center, spacing: 8) {
                    BuildRailView(session: session, rail: $buildRail, layout: layout)
                    BuildDrawerView(
                        session: session, rail: $buildRail, layout: layout,
                        availableHeight: proxy.size.height - topBand
                    )
                    .padding(.top, topBand)
                    .frame(maxHeight: .infinity)
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            }
            .tvFocusSection()
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
