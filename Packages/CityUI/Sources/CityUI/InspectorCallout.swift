import CityCore
import CoreGraphics
import Foundation
import SwiftUI

/// Places the inspector callout next to the selected building. Spec:
/// `platform-shells` / Inspector callout.
public enum InspectorCalloutLayout {
    public static let width: CGFloat = 220

    /// A TV is read from across the room: at 220 points the market rows
    /// wrap mid-word on a 1920-point screen.
    public static func width(for idiom: HUDIdiom) -> CGFloat {
        switch idiom {
        case .tv: 520
        // "Its road doesn't reach a warehouse or the town center" breaks "cen-ter" at 220 points; a
        // phone has the width to spare.
        case .phone: 264
        case .pad, .mac: width
        }
    }

    /// Gap from the building's edge: beside it in the rail layout, below it
    /// in the dock layout.
    public static let sideGap: CGFloat = 14
    public static let belowGap: CGFloat = 12
    /// Tiles around a selected road whose buildings the callout leaves visible: it would otherwise
    /// sit on the farm the road leads to.
    static let neighbourReach = 3
    static let spacing: CGFloat = 6
    static let padding = CGSize(width: 12, height: 10)

    /// Which side of the building the callout ended up on.
    public enum Side: Equatable, Sendable {
        case trailing, leading, below, above
    }

    /// The buildings a selected road's callout should leave visible: those within `neighbourReach`
    /// tiles that are not roads. A road beside other roads would otherwise have no clear side. Other
    /// selections keep the plain placement and get none.
    static func neighbours(of tile: TileCoordinate, in world: World) -> [Building] {
        guard let own = world.occupiedTiles[tile], world.buildings[own]?.kind == .road else { return [] }
        var found: [EntityID: Building] = [:]
        for dy in -neighbourReach ... neighbourReach {
            for dx in -neighbourReach ... neighbourReach {
                let near = TileCoordinate(x: tile.x + dx, y: tile.y + dy)
                if let id = world.occupiedTiles[near], let building = world.buildings[id], building.kind != .road {
                    found[id] = building
                }
            }
        }
        return found.values.sorted { $0.id.raw < $1.id.raw }
    }

    /// The callout's top-left corner for a building centered on `anchor`,
    /// flipped to the other side when the preferred one would leave
    /// `bounds`, then clamped into `bounds`. `avoiding` are the screen
    /// rects of the neighbouring buildings the callout should not hide:
    /// when the preferred side would cover one, the opposite side and then
    /// the two beside the building are tried, and the first that fits
    /// without covering any wins.
    public static func place(
        anchor: CGPoint,
        buildingHalfSize half: CGSize,
        calloutSize size: CGSize,
        bounds: CGRect,
        placement: HUDDock,
        avoiding: [CGRect] = []
    ) -> (origin: CGPoint, side: Side) {
        let sides: [Side] = switch placement {
        case .leftRail: [.trailing, .leading, .below, .above]
        case .bottomDock: [.below, .above, .trailing, .leading]
        }
        let candidates = sides.map { candidate($0, anchor: anchor, half: half, size: size, bounds: bounds) }
        // The preferred side or its opposite, as before: used when no side clears every neighbour.
        let fallback = candidates[0].fits ? candidates[0] : candidates[1]
        guard !avoiding.isEmpty else { return (fallback.origin, fallback.side) }
        let clear = candidates.first { candidate in
            candidate.fits && !avoiding.contains { $0.intersects(CGRect(origin: candidate.origin, size: size)) }
        }
        let chosen = clear ?? fallback
        return (chosen.origin, chosen.side)
    }

    private struct Candidate {
        let side: Side
        let origin: CGPoint
        /// The unclamped origin kept the callout inside `bounds` along the side's own axis.
        let fits: Bool
    }

    private static func candidate(
        _ side: Side, anchor: CGPoint, half: CGSize, size: CGSize, bounds: CGRect
    ) -> Candidate {
        var origin: CGPoint
        let fits: Bool
        switch side {
        case .trailing:
            origin = CGPoint(x: anchor.x + half.width + sideGap, y: anchor.y - size.height / 2)
            fits = origin.x + size.width <= bounds.maxX
        case .leading:
            origin = CGPoint(x: anchor.x - half.width - sideGap - size.width, y: anchor.y - size.height / 2)
            fits = origin.x >= bounds.minX
        case .below:
            origin = CGPoint(x: anchor.x - size.width / 2, y: anchor.y + half.height + belowGap)
            fits = origin.y + size.height <= bounds.maxY
        case .above:
            origin = CGPoint(x: anchor.x - size.width / 2, y: anchor.y - half.height - belowGap - size.height)
            fits = origin.y >= bounds.minY
        }
        origin.x = clamp(origin.x, length: size.width, from: bounds.minX, to: bounds.maxX)
        origin.y = clamp(origin.y, length: size.height, from: bounds.minY, to: bounds.maxY)
        return Candidate(side: side, origin: origin, fits: fits)
    }

    /// Where the HUD's top bar ends: the minimap's top in the dock layout
    /// and the callout's highest edge.
    static func topBarBottom(topInset: CGFloat, layout: HUDLayout) -> CGFloat {
        topInset + layout.margin + layout.controlHeight + 8
    }

    /// The safe area minus the pill row, rail and dock, the minimap's band
    /// while it shows, and the first-steps card's column (or, collapsed,
    /// its capsule's band) while it shows. Spec: `platform-shells` /
    /// Minimap layout, First-hour guide.
    public static func freeArea(
        size: CGSize, insets: EdgeInsets, layout: HUDLayout, showsMinimap: Bool, showsFirstSteps: Bool = false,
        showsOrdersBoard: Bool = false
    ) -> CGRect {
        // The open board collapses the first-steps card (`Order board layout`).
        let layout = showsOrdersBoard ? layout.withFirstStepsCollapsed : layout
        let margin = layout.margin
        var top = topBarBottom(topInset: insets.top, layout: layout)
        let left = insets.leading + margin + layout.railInset
        var right = size.width - insets.trailing - margin
        var bottom = size.height - insets.bottom - margin - (layout.placement == .bottomDock ? 74 : 0)
        // The card stacks under the minimap when both sit top-right.
        var rightColumnTop = top
        if showsMinimap {
            let minimap = MinimapLayout.frame(in: size, insets: insets, layout: layout)
            switch MinimapLayout.corner(for: layout) {
            case .bottomTrailing: bottom = min(bottom, minimap.minY - MinimapLayout.gap)
            case .topTrailing:
                top = max(top, minimap.maxY + MinimapLayout.gap)
                rightColumnTop = top
            }
        }
        if showsFirstSteps {
            if layout.collapsesFirstSteps {
                top = max(top, rightColumnTop + layout.focusableHeight(FirstStepsCardView.capsuleHeight) + MinimapLayout.gap)
            } else {
                right = min(right, size.width - insets.trailing - margin - FirstStepsCardView.width - MinimapLayout.gap)
            }
        }
        if showsOrdersBoard {
            right = min(right, size.width - insets.trailing - margin - OrderBoardLayout.width(for: layout.idiom) - MinimapLayout.gap)
        }
        return CGRect(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
    }

    private static func clamp(_ value: CGFloat, length: CGFloat, from low: CGFloat, to high: CGFloat) -> CGFloat {
        max(low, min(value, high - length))
    }
}

/// Spec: `platform-shells` / Inspector callout.
public extension GameSession {
    /// Inspector model derived from the current snapshot + selection.
    var inspector: InspectorViewModel {
        guard let selectedTile else { return InspectorViewModel(bullets: []) }
        return InspectorViewModel.make(from: world.snapshot(), tile: selectedTile, buildings: world.buildings)
    }

    /// The callout's Demolish: demolishes the selected building and clears
    /// the selection.
    func demolishSelection() {
        guard let tile = selectedTile else { return }
        enqueue(.demolish(at: tile))
        selectedTile = nil
    }
}

/// The inspector as a callout pinned next to the selected building.
struct InspectorCalloutView<Actions: View>: View {
    let session: GameSession
    let viewModel: InspectorViewModel
    let tile: TileCoordinate
    let layout: HUDLayout
    let showsMinimap: Bool
    @Binding var isExpanded: Bool
    @ViewBuilder let actions: () -> Actions
    @State private var size = CGSize(width: InspectorCalloutLayout.width, height: 120)
    /// The details' full height, so their scroll view is no taller.
    @State private var detailsHeight: CGFloat = 0
    /// The scroll view's current height; the rest of `size` is the
    /// header, footer, spacing and padding.
    @State private var scrollHeight: CGFloat = 0

    var body: some View {
        // The safe area is read before it is ignored: inside, the insets
        // read zero, and on Apple TV the callout then ran under the top bar.
        GeometryReader { safe in
            fullScreen(insets: safe.safeAreaInsets)
        }
    }

    private func fullScreen(insets: EdgeInsets) -> some View {
        // Full-screen coordinates, the same space the world view projects into.
        GeometryReader { proxy in
            let (anchor, half) = projection(viewSize: proxy.size)
            let bounds = InspectorCalloutLayout.freeArea(
                size: proxy.size, insets: insets, layout: layout, showsMinimap: showsMinimap,
                showsFirstSteps: session.firstStepsGuide != nil,
                showsOrdersBoard: session.isOrdersPresented && OrderBoardLayout.presentation(
                    in: proxy.size, insets: insets, layout: layout, showsMinimap: showsMinimap,
                    showsFirstSteps: session.firstStepsGuide != nil
                ) == .column
            )
            let placed = InspectorCalloutLayout.place(
                anchor: anchor,
                buildingHalfSize: half,
                calloutSize: size,
                bounds: bounds,
                placement: layout.placement,
                avoiding: neighbourRects(viewSize: proxy.size)
            )
            card(maxHeight: bounds.height)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("inspector.callout")
                .overlay(alignment: .topLeading) { pointer(side: placed.side, anchor: anchor, origin: placed.origin) }
                .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
                .offset(x: placed.origin.x, y: placed.origin.y)
        }
        .ignoresSafeArea()
    }

    /// The building's center and half extent on screen, from its footprint.
    private func projection(viewSize: CGSize) -> (CGPoint, CGSize) {
        guard let id = session.world.occupiedTiles[tile], let building = session.world.buildings[id] else {
            return (PlacementHUDLayout.viewPoint(forTile: tile, camera: session.world.camera, viewSize: viewSize), .zero)
        }
        return projection(of: building, viewSize: viewSize)
    }

    private func projection(of building: Building, viewSize: CGSize) -> (CGPoint, CGSize) {
        let camera = session.world.camera
        let footprint = building.footprint
        let first = PlacementHUDLayout.viewPoint(forTile: building.anchor, camera: camera, viewSize: viewSize)
        let last = PlacementHUDLayout.viewPoint(
            forTile: TileCoordinate(x: building.anchor.x + footprint.width - 1, y: building.anchor.y + footprint.height - 1),
            camera: camera,
            viewSize: viewSize
        )
        let span = CGFloat(footprint.width + footprint.height) / 2 * CGFloat(camera.zoom)
        return (
            CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2),
            CGSize(width: span * 32, height: span * 16)
        )
    }

    /// Screen rects of the buildings near the selection, taller than their footprint for the roof and
    /// the status icon above it.
    private func neighbourRects(viewSize: CGSize) -> [CGRect] {
        let zoom = CGFloat(session.world.camera.zoom)
        let headroom = 40 * zoom + 24
        return InspectorCalloutLayout.neighbours(of: tile, in: session.world).map { building in
            let (center, half) = projection(of: building, viewSize: viewSize)
            return CGRect(
                x: center.x - half.width, y: center.y - half.height - headroom,
                width: half.width * 2, height: half.height * 2 + headroom
            )
        }
    }

    /// The details, such as the town center market, scroll when the
    /// callout would outgrow `maxHeight`, so Less and Demolish stay on
    /// screen.
    private func card(maxHeight: CGFloat) -> some View {
        let keyLines = viewModel.keyLines
        let rest = viewModel.bullets.filter { !keyLines.contains($0) && !$0.hasPrefix("Kind:") }
        let room = max(0, maxHeight - (size.height - scrollHeight))
        return VStack(alignment: .leading, spacing: InspectorCalloutLayout.spacing) {
            header(keyLines)
            if isExpanded {
                // The scroll view takes what the header and footer leave,
                // and no more than the details need.
                ScrollView {
                    details(rest)
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { detailsHeight = $0 }
                }
                .frame(maxHeight: min(detailsHeight, room))
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { scrollHeight = $0 }
                // tvOS scroll views draw outside their bounds for focus effects.
                .clipped()
            } else {
                details(rest)
            }
            footer
        }
        .padding(.horizontal, InspectorCalloutLayout.padding.width)
        .padding(.vertical, InspectorCalloutLayout.padding.height)
        .frame(width: InspectorCalloutLayout.width(for: layout.idiom), alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    /// Title, tier, residents meter and key lines.
    private func header(_ keyLines: [String]) -> some View {
        VStack(alignment: .leading, spacing: InspectorCalloutLayout.spacing) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(viewModel.title ?? "Building").font(.headline)
                Spacer(minLength: 0)
                if let tier = viewModel.tier {
                    Text(tier).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let fill = viewModel.residentsFill {
                residentsMeter(fill)
            }
            ForEach(keyLines, id: \.self) { line in
                if let problem = viewModel.problem, line.hasPrefix("Problem:") {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    InspectorKeyLine(line: line)
                }
            }
        }
    }

    /// The other lines and the building's controls, the market among them.
    private func details(_ rest: [String]) -> some View {
        InspectorView(
            viewModel: viewModel,
            lines: isExpanded ? rest : [],
            isFramed: false,
            townMarket: isExpanded ? session.townMarket : nil,
            onCommission: session.commissionArt,
            onPickExport: session.pickExport,
            onStartRoute: { session.beginRouteAuthoring(from: $0) },
            onMarketTrade: session.tradeAtMarket
        )
        .disabled(session.isGameOver)
        .foregroundStyle(.primary.opacity(0.75))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Details or Less, the actions, and Demolish.
    private var footer: some View {
        HStack(spacing: 8) {
            Button(isExpanded ? "Less" : "Details") { isExpanded.toggle() }
            Spacer(minLength: 0)
            actions()
            if viewModel.rival == nil {
                Button(viewModel.demolish?.title ?? "Demolish", role: .destructive, action: session.demolishSelection)
                    .foregroundStyle(.red)
                    .disabled(session.isGameOver || viewModel.demolish?.isEnabled == false)
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.borderless)
    }

    private func residentsMeter(_ fill: Double) -> some View {
        Capsule()
            .fill(HUDMetrics.fill)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(Color.green).frame(width: proxy.size.width * fill)
                }
            }
            .accessibilityLabel(GameText.string("a11y.residentsPercent", Int((fill * 100).rounded())))
    }

    /// A diamond on the edge facing the building.
    private func pointer(side: InspectorCalloutLayout.Side, anchor: CGPoint, origin: CGPoint) -> some View {
        let alongY = min(max(anchor.y - origin.y - 6, 10), size.height - 22)
        let alongX = min(max(anchor.x - origin.x - 6, 10), size.width - 22)
        let offset = switch side {
        case .trailing: CGSize(width: -6, height: alongY)
        case .leading: CGSize(width: size.width - 6, height: alongY)
        case .below: CGSize(width: alongX, height: -6)
        case .above: CGSize(width: alongX, height: size.height - 6)
        }
        return Rectangle()
            .fill(.regularMaterial)
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(45))
            .offset(offset)
    }
}

/// One key line of the callout. It wraps at word gaps as far as it needs, so a
/// merchant house's stock of six goods never truncates at the callout width.
/// Spec: `platform-shells` / Market lines in the inspector.
struct InspectorKeyLine: View {
    let line: String

    var body: some View {
        Text(line).font(.caption.monospaced()).fixedSize(horizontal: false, vertical: true)
    }
}
