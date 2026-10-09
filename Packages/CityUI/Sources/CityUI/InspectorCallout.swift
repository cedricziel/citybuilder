import CityCore
import CoreGraphics
import Foundation
import SwiftUI

/// Places the inspector callout next to the selected building. Spec:
/// `platform-shells` / Inspector callout.
public enum InspectorCalloutLayout {
    public static let width: CGFloat = 220
    public static let margin: CGFloat = 8
    /// Gap between the building's center and the callout.
    public static let gap: CGFloat = 48

    /// Top-left corner of a callout of `calloutSize` for a building whose
    /// center is `anchor`, clamped inside `viewSize`.
    public static func origin(anchor: CGPoint, calloutSize: CGSize, viewSize: CGSize, placement: HUDDock) -> CGPoint {
        let raw = switch placement {
        case .leftRail:
            CGPoint(x: anchor.x + gap, y: anchor.y - calloutSize.height / 2)
        case .bottomDock:
            CGPoint(x: anchor.x - calloutSize.width / 2, y: anchor.y + gap)
        }
        return CGPoint(
            x: clamp(raw.x, length: calloutSize.width, in: viewSize.width),
            y: clamp(raw.y, length: calloutSize.height, in: viewSize.height)
        )
    }

    private static func clamp(_ value: CGFloat, length: CGFloat, in extent: CGFloat) -> CGFloat {
        max(margin, min(value, extent - margin - length))
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
    let placement: HUDDock
    @ViewBuilder let actions: () -> Actions
    @State private var isExpanded = false
    @State private var size = CGSize(width: InspectorCalloutLayout.width, height: 120)

    var body: some View {
        GeometryReader { proxy in
            let anchor = PlacementHUDLayout.viewPoint(forTile: tile, camera: session.world.camera, viewSize: proxy.size)
            let origin = InspectorCalloutLayout.origin(
                anchor: anchor, calloutSize: size, viewSize: proxy.size, placement: placement
            )
            card
                .overlay(alignment: .topLeading) { pointer(anchor: anchor, origin: origin) }
                .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
                .offset(x: origin.x, y: origin.y)
        }
        .ignoresSafeArea()
    }

    private var card: some View {
        let keyLines = viewModel.keyLines
        let rest = viewModel.bullets.filter { !keyLines.contains($0) }
        return VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.title ?? "Building").font(.headline)
            ForEach(keyLines, id: \.self) { line in
                Text(line).font(.caption.monospaced()).lineLimit(2)
            }
            InspectorView(
                viewModel: viewModel,
                lines: isExpanded ? rest : [],
                isFramed: false,
                onCommission: session.commissionArt,
                onPickExport: session.pickExport,
                onStartRoute: { session.beginRouteAuthoring(from: $0) }
            )
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

    /// A diamond on the edge facing the building, while the building is
    /// on that side.
    @ViewBuilder
    private func pointer(anchor: CGPoint, origin: CGPoint) -> some View {
        let diamond = Rectangle()
            .fill(.regularMaterial)
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(45))
        switch placement {
        case .leftRail where anchor.x < origin.x:
            diamond.offset(x: -6, y: min(max(anchor.y - origin.y, 12), size.height - 24))
        case .bottomDock where anchor.y < origin.y:
            diamond.offset(x: min(max(anchor.x - origin.x, 12), size.width - 24), y: -6)
        default:
            EmptyView()
        }
    }
}
