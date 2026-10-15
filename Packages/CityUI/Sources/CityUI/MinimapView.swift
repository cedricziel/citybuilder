import CityCore
import SwiftUI

/// Draws the minimap: the cached terrain image, the building footprints,
/// the ship dots and, on top, the camera's visible area. The bottom layer
/// reads only `MinimapModel`, so it redraws when the model changes rather
/// than on every tick; only the camera layer follows the world. Spec:
/// `platform-shells` / Minimap. Design D3.
struct MinimapCanvas: View {
    let session: GameSession
    /// The world view's size, for the camera rectangle.
    let worldViewSize: CGSize

    var body: some View {
        MinimapMarkersLayer(model: session.minimap)
            .overlay { MinimapCameraLayer(session: session, worldViewSize: worldViewSize) }
    }
}

private struct MinimapMarkersLayer: View {
    let model: MinimapModel

    var body: some View {
        Canvas { context, size in
            let projection = model.projection(size: size)
            if let image = model.terrainImage {
                context.draw(Image(decorative: image, scale: 1).interpolation(.medium), in: CGRect(origin: .zero, size: size))
            }
            for marker in model.buildings {
                // The outline keeps azure and emerald markers apart from
                // water and forest.
                let footprint = Self.footprint(marker, projection: projection)
                context.fill(footprint, with: .color(Color(marker.colour)))
                context.stroke(footprint, with: .color(.white.opacity(0.85)), lineWidth: 0.75)
            }
            let radius = max(size.width / 120, 1.5)
            for ship in model.ships {
                let center = projection.point(tileX: ship.x, tileY: ship.y)
                let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.fill(dot, with: .color(Color(ship.colour)))
                context.stroke(dot, with: .color(.white), lineWidth: 0.75)
            }
        }
    }

    /// A footprint's diamond, from the outer corners of its tiles, at
    /// least `minimumHalfWidth` points wide each way so a house stays
    /// visible on a large map.
    private static func footprint(_ marker: MinimapBuildingMarker, projection: MinimapProjection) -> Path {
        let minX = Double(marker.anchor.x) - 0.5
        let minY = Double(marker.anchor.y) - 0.5
        let maxX = minX + Double(marker.width)
        let maxY = minY + Double(marker.height)
        let top = projection.point(tileX: minX, tileY: minY)
        let right = projection.point(tileX: maxX, tileY: minY)
        let bottom = projection.point(tileX: maxX, tileY: maxY)
        let left = projection.point(tileX: minX, tileY: maxY)
        let center = CGPoint(x: (left.x + right.x) / 2, y: (top.y + bottom.y) / 2)
        let grow = max(1, minimumHalfWidth / max((right.x - left.x) / 2, 0.001))
        func scaled(_ point: CGPoint) -> CGPoint {
            CGPoint(x: center.x + (point.x - center.x) * grow, y: center.y + (point.y - center.y) * grow)
        }
        return Path { path in
            path.addLines([top, right, bottom, left].map(scaled))
            path.closeSubpath()
        }
    }

    private static let minimumHalfWidth: CGFloat = 2
}

private struct MinimapCameraLayer: View {
    let session: GameSession
    let worldViewSize: CGSize

    var body: some View {
        let model = session.minimap
        let camera = model.camera
        Canvas { context, size in
            let frame = model.projection(size: size).cameraRect(camera: camera, viewSize: worldViewSize)
                .intersection(CGRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75))
            if !frame.isNull {
                context.stroke(Path(frame), with: .color(.white), lineWidth: 1.5)
            }
        }
    }
}

extension Color {
    init(_ rgba: MinimapRGBA) {
        self.init(red: Double(rgba.red) / 255, green: Double(rgba.green) / 255, blue: Double(rgba.blue) / 255)
    }
}

#if !os(tvOS)
/// The corner minimap: the canvas in a card. A tap or click glides the
/// camera there, or jumps it under Reduce Motion; a drag moves it at once.
/// The card takes the touches, so the map's own gestures never see them.
/// Spec: `platform-shells` / Minimap moves the camera.
struct MinimapCard: View {
    let session: GameSession
    let layout: HUDLayout
    let worldViewSize: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false

    var body: some View {
        let size = MinimapLayout.mapSize(for: layout)
        MinimapCanvas(session: session, worldViewSize: worldViewSize)
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(drag(size: size))
            .padding(MinimapLayout.padding)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: HUDMetrics.cornerRadius, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Minimap")
            .accessibilityIdentifier("hud.minimap")
    }

    private func drag(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let travel = hypot(value.translation.width, value.translation.height)
                if isDragging || travel > 3 {
                    isDragging = true
                    move(to: value.location, size: size, animated: false)
                }
            }
            .onEnded { value in
                if !isDragging {
                    move(to: value.location, size: size, animated: !reduceMotion)
                }
                isDragging = false
            }
    }

    private func move(to point: CGPoint, size: CGSize, animated: Bool) {
        session.centerCamera(onMinimapPoint: point, projection: session.minimap.projection(size: size), animated: animated)
    }
}
#endif
