import CityCore
import CoreGraphics
import Foundation
import SwiftUI

/// Places the inspector callout next to the selected building. Spec:
/// `platform-shells` / Inspector callout.
public enum InspectorCalloutLayout {
    public static let width: CGFloat = 220
    /// Gap from the building's edge: beside it in the rail layout, below it
    /// in the dock layout.
    public static let sideGap: CGFloat = 14
    public static let belowGap: CGFloat = 12

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

    private static func clamp(_ value: CGFloat, length: CGFloat, from low: CGFloat, to high: CGFloat) -> CGFloat {
        max(low, min(value, high - length))
    }
}

/// Spec: `platform-shells` / Inspector callout.
public extension GameSession {
    /// The callout's Demolish: demolishes the selected building and clears
    /// the selection.
    func demolishSelection() {
        guard let tile = selectedTile else { return }
        world.enqueue(.demolish(at: tile))
        selectedTile = nil
    }
}

/// The inspector as a callout pinned next to the selected building.
struct InspectorCalloutView<Actions: View>: View {
    let session: GameSession
    let viewModel: InspectorViewModel
    let tile: TileCoordinate
    let layout: HUDLayout
    @Binding var isExpanded: Bool
    @ViewBuilder let actions: () -> Actions
    @State private var size = CGSize(width: InspectorCalloutLayout.width, height: 120)

    var body: some View {
        // Full-screen coordinates, the same space the world view projects into.
        GeometryReader { proxy in
            let (anchor, half) = projection(viewSize: proxy.size)
            let placed = InspectorCalloutLayout.place(
                anchor: anchor,
                buildingHalfSize: half,
                calloutSize: size,
                bounds: freeArea(size: proxy.size, insets: proxy.safeAreaInsets),
                placement: layout.placement
            )
            card
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

    /// The safe area minus the pill row, rail and dock.
    private func freeArea(size: CGSize, insets: EdgeInsets) -> CGRect {
        let margin = layout.margin
        let top = insets.top + margin + layout.controlHeight + 8
        let left = insets.leading + margin + (layout.placement == .leftRail ? layout.railWidth + 8 : 0)
        let right = size.width - insets.trailing - margin
        let bottom = size.height - insets.bottom - margin - (layout.placement == .bottomDock ? 74 : 0)
        return CGRect(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
    }

    private var card: some View {
        let keyLines = viewModel.keyLines
        let rest = viewModel.bullets.filter { !keyLines.contains($0) && !$0.hasPrefix("Kind:") }
        return VStack(alignment: .leading, spacing: 6) {
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
            InspectorView(
                viewModel: viewModel,
                lines: isExpanded ? rest : [],
                isFramed: false,
                onCommission: session.commissionArt,
                onPickExport: session.pickExport,
                onStartRoute: { session.beginRouteAuthoring(from: $0) }
            )
            .foregroundStyle(.primary.opacity(0.75))
            HStack(spacing: 8) {
                Button(isExpanded ? "Less" : "Details") { isExpanded.toggle() }
                Spacer(minLength: 0)
                actions()
                if viewModel.rival == nil {
                    Button("Demolish", role: .destructive, action: session.demolishSelection)
                        .foregroundStyle(.red)
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: InspectorCalloutLayout.width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
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
