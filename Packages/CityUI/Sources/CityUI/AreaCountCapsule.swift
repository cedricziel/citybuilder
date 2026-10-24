import CityCore
import SwiftUI

/// What the ghost's site reaches, in a capsule just above the ghost's
/// roof that moves with it. Spec: `platform-shells` / Count capsule over
/// the ghost.
struct AreaCountCapsule: View {
    let session: GameSession
    let idiom: HUDIdiom

    var body: some View {
        // Full-screen coordinates, the same space the world view projects into.
        GeometryReader { proxy in
            if let model = session.areaCountCapsule {
                label(model)
                    .fixedSize()
                    // A zero-size frame at the point, content bottom-aligned: the capsule rises from it.
                    .frame(width: 0, height: 0, alignment: .bottom)
                    .position(AreaCountCapsuleLayout.point(
                        above: model.kind, at: model.anchor, camera: session.world.camera, viewSize: proxy.size
                    ))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func label(_ model: AreaCountCapsuleModel) -> some View {
        let metrics = AreaCountCapsuleLayout.metrics(for: idiom)
        return Text(model.text)
            .font(.system(size: metrics.fontSize, weight: .semibold))
            .lineLimit(1)
            .padding(.vertical, metrics.padding.height)
            .padding(.horizontal, metrics.padding.width)
            .foregroundStyle(foreground(model.tone))
            .background { background(model.tone) }
            .accessibilityIdentifier("area.count")
    }

    private func foreground(_ tone: AreaCountCapsuleModel.Tone) -> Color {
        switch tone {
        case .neutral: .primary
        case .low: Color(red: 0.165, green: 0.09, blue: 0)
        case .none: .white
        }
    }

    @ViewBuilder
    private func background(_ tone: AreaCountCapsuleModel.Tone) -> some View {
        switch tone {
        case .neutral: Capsule().fill(.regularMaterial).shadow(color: .black.opacity(0.15), radius: 4, y: 1)
        case .low: Capsule().fill(Color.orange.opacity(0.88))
        case .none: Capsule().fill(Color.red.opacity(0.85))
        }
    }
}

/// Where the count capsule sits and how large it is on each device.
enum AreaCountCapsuleLayout {
    /// How far a workshop's sprite rises above its plot's top corner at
    /// zoom 1, so the capsule clears the roof.
    static let roofLift: CGFloat = 44
    /// Space between the roof and the capsule.
    static let gap: CGFloat = 6

    struct Metrics: Equatable {
        let fontSize: CGFloat
        /// Horizontal and vertical padding.
        let padding: CGSize
    }

    static func metrics(for idiom: HUDIdiom) -> Metrics {
        switch idiom {
        case .phone, .pad: Metrics(fontSize: 13, padding: CGSize(width: 10, height: 4))
        case .mac: Metrics(fontSize: 12, padding: CGSize(width: 9, height: 3))
        case .tv: Metrics(fontSize: 24, padding: CGSize(width: 20, height: 8))
        }
    }

    /// The point the capsule's bottom centre sits on: over the middle of
    /// a `kind` plot at `anchor`, a roof's height above its top corner.
    static func point(above kind: BuildingKind, at anchor: TileCoordinate, camera: Camera, viewSize: CGSize) -> CGPoint {
        let footprint = BuildingCatalog.spec(for: kind).footprint
        let first = PlacementHUDLayout.viewPoint(forTile: anchor, camera: camera, viewSize: viewSize)
        let last = PlacementHUDLayout.viewPoint(
            forTile: TileCoordinate(x: anchor.x + footprint.width - 1, y: anchor.y + footprint.height - 1),
            camera: camera, viewSize: viewSize
        )
        let zoom = CGFloat(camera.zoom)
        let middle = CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2)
        let top = middle.y - CGFloat(footprint.width + footprint.height) / 2 * PlacementHUDLayout.halfTileHeight * zoom
        return CGPoint(x: middle.x, y: top - roofLift * zoom - gap)
    }
}
