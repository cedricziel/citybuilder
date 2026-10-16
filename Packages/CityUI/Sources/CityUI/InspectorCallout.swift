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
        idiom == .tv ? 520 : width
    }

    /// Gap from the building's edge: beside it in the rail layout, below it
    /// in the dock layout.
    public static let sideGap: CGFloat = 14
    public static let belowGap: CGFloat = 12
    static let spacing: CGFloat = 6
    static let padding = CGSize(width: 12, height: 10)

    /// Which side of the building the callout ended up on.
    public enum Side: Equatable, Sendable {
        case trailing, leading, below, above
    }

    /// The callout's top-left corner for a building centered on `anchor`,
    /// flipped to the other side when the preferred one would leave
    /// `bounds`, then clamped into `bounds`.
    public static func place(
        anchor: CGPoint,
        buildingHalfSize half: CGSize,
        calloutSize size: CGSize,
        bounds: CGRect,
        placement: HUDDock
    ) -> (origin: CGPoint, side: Side) {
        var origin: CGPoint
        let side: Side
        switch placement {
        case .leftRail:
            origin = CGPoint(x: anchor.x + half.width + sideGap, y: anchor.y - size.height / 2)
            if origin.x + size.width > bounds.maxX {
                origin.x = anchor.x - half.width - sideGap - size.width
                side = .leading
            } else {
                side = .trailing
            }
        case .bottomDock:
            origin = CGPoint(x: anchor.x - size.width / 2, y: anchor.y + half.height + belowGap)
            if origin.y + size.height > bounds.maxY {
                origin.y = anchor.y - half.height - belowGap - size.height
                side = .above
            } else {
                side = .below
            }
        }
        origin.x = clamp(origin.x, length: size.width, from: bounds.minX, to: bounds.maxX)
        origin.y = clamp(origin.y, length: size.height, from: bounds.minY, to: bounds.maxY)
        return (origin, side)
    }

    /// Where the HUD's top bar ends: the minimap's top in the dock layout
    /// and the callout's highest edge.
    static func topBarBottom(topInset: CGFloat, layout: HUDLayout) -> CGFloat {
        topInset + layout.margin + layout.controlHeight + 8
    }

    /// The safe area minus the pill row, rail and dock, and the minimap's
    /// band while it shows. Spec: `platform-shells` / Minimap layout.
    public static func freeArea(size: CGSize, insets: EdgeInsets, layout: HUDLayout, showsMinimap: Bool) -> CGRect {
        let margin = layout.margin
        var top = topBarBottom(topInset: insets.top, layout: layout)
        let left = insets.leading + margin + layout.railInset
        let right = size.width - insets.trailing - margin
        var bottom = size.height - insets.bottom - margin - (layout.placement == .bottomDock ? 74 : 0)
        if showsMinimap {
            let minimap = MinimapLayout.frame(in: size, insets: insets, layout: layout)
            switch MinimapLayout.corner(for: layout) {
            case .bottomTrailing: bottom = min(bottom, minimap.minY - MinimapLayout.gap)
            case .topTrailing: top = max(top, minimap.maxY + MinimapLayout.gap)
            }
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
                size: proxy.size, insets: insets, layout: layout, showsMinimap: showsMinimap
            )
            let placed = InspectorCalloutLayout.place(
                anchor: anchor,
                buildingHalfSize: half,
                calloutSize: size,
                bounds: bounds,
                placement: layout.placement
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
        let camera = session.world.camera
        guard let id = session.world.occupiedTiles[tile], let building = session.world.buildings[id] else {
            return (PlacementHUDLayout.viewPoint(forTile: tile, camera: camera, viewSize: viewSize), .zero)
        }
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
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
                    Text(line).font(.caption.monospaced()).lineLimit(2)
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
                Button("Demolish", role: .destructive, action: session.demolishSelection)
                    .foregroundStyle(.red)
                    .disabled(session.isGameOver)
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
            .accessibilityLabel("Residents \(Int((fill * 100).rounded())) percent")
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
