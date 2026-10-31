#if os(tvOS)
import CityCore
import QuartzCore
import SwiftUI

/// The Apple TV map: the remote's input host, the reticle, and the HUD's
/// Back and Play/Pause handling. Spec: `tv-remote-controls`. Tasks 2.12,
/// 2.13.
extension CityRootView {
    func tvMapLayer(_ map: some View) -> some View {
        map.overlay {
            if let tvRemote {
                TVMapOverlay(remote: tvRemote)
            }
        }
        .onAppear {
            if tvRemote == nil {
                tvRemote = TVRemoteController(session: session)
            }
        }
        .onChange(of: session.selectedTool) { _, tool in
            tvRemote?.toolChanged(to: tool, at: CACurrentMediaTime())
        }
    }
}

/// The input host and the reticle. SwiftUI wraps the host's focusable
/// view in its own focus item, so focus moves onto the map through
/// `@FocusState`; a UIKit focus request alone is turned down while a
/// SwiftUI control holds focus.
struct TVMapOverlay: View {
    let remote: TVRemoteController
    @FocusState private var mapFocused: Bool

    var body: some View {
        ZStack {
            TVMapInputHost(remote: remote)
                .focused($mapFocused)
            TVReticleOverlay(remote: remote)
                .allowsHitTesting(false)
        }
        .onAppear { mapFocused = remote.focus == .map }
        .onChange(of: remote.focus) { _, focus in
            mapFocused = focus == .map
        }
    }
}

/// In the HUD and the inspector callout the focus engine owns the remote:
/// Back closes an open drawer or returns to the map, and Play/Pause
/// returns to the map.
struct TVHUDCommands: ViewModifier {
    let root: CityRootView
    var isInspector = false

    /// While the map owns the remote, the HUD takes no focus, so the focus
    /// engine cannot land on it. While focus moves into the inspector
    /// callout, the rest of the HUD stays out of the way too.
    private var isDisabled: Bool {
        guard let remote = root.tvRemote else { return false }
        return remote.focus == .map || (remote.focusesInspector && !isInspector)
    }

    func body(content: Content) -> some View {
        content
            .disabled(isDisabled)
            .onExitCommand {
                if root.buildRail.openDrawer != nil {
                    root.buildRail.close()
                } else {
                    root.tvRemote?.send(.back, at: CACurrentMediaTime())
                }
            }
            .onPlayPauseCommand {
                let now = CACurrentMediaTime()
                root.tvRemote?.send(.playPauseDown, at: now)
                root.tvRemote?.send(.playPauseUp, at: now)
            }
    }
}

/// The reticle at the screen center: the target tile's outline in the
/// style of the armed tool, an arrow on each tile a click would step to
/// (dimmed where the map ends), and the tooltip of a building the reticle
/// rests on. Design D1, D2, D6.
struct TVReticleOverlay: View {
    let remote: TVRemoteController

    private var session: GameSession {
        remote.session
    }

    var body: some View {
        if remote.focus == .map {
            let zoom = session.world.camera.zoom
            let halfWidth = 32 * zoom
            let halfHeight = 16 * zoom
            ZStack {
                ReticleDiamond()
                    .stroke(color, lineWidth: 4)
                    .frame(width: halfWidth * 2, height: halfHeight * 2)
                ForEach(RemoteDirection.allCases, id: \.self) { direction in
                    hint(direction).offset(Self.offset(direction, halfWidth: halfWidth, halfHeight: halfHeight))
                }
                .accessibilityHidden(true)
                if let id = remote.tooltipBuilding, let building = session.world.buildings[id] {
                    Text(BuildTool.place(building.kind).displayName)
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .offset(x: halfWidth * 3 + 80, y: -halfHeight * 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("tv.reticle")
            .accessibilityLabel(GameText.string("a11y.reticle", "\(session.reticleTile.x)", "\(session.reticleTile.y)"))
        }
    }

    private var color: Color {
        switch session.reticleStyle {
        case .idle: .white
        case .painting: .yellow
        case .demolish: .red
        }
    }

    private func hint(_ direction: RemoteDirection) -> some View {
        let open = session.world.contains(session.reticleHint(direction))
        return Image(systemName: Self.arrow(direction))
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(.black.opacity(0.45), in: Circle())
            .opacity(open ? 1 : 0.3)
    }

    private static func arrow(_ direction: RemoteDirection) -> String {
        switch direction {
        case .up: "arrow.up.right"
        case .right: "arrow.down.right"
        case .down: "arrow.down.left"
        case .left: "arrow.up.left"
        }
    }

    /// Along the diagonal to the neighbouring tile, from the same iso
    /// projection as the map (x follows dx - dy, y follows dx + dy), and a
    /// little beyond it, so the arrows clear the reticle's outline.
    private static func offset(_ direction: RemoteDirection, halfWidth: Double, halfHeight: Double) -> CGSize {
        let step = direction.nudge.tileOffset
        let reach = 1.75
        return CGSize(
            width: Double(step.dx - step.dy) * halfWidth * reach,
            height: Double(step.dx + step.dy) * halfHeight * reach
        )
    }
}

private struct ReticleDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        }
    }
}

/// Apple TV has no pinch: the top bar zooms by 1.5 per press. Spec:
/// `tv-remote-controls` / Zoom without pinch.
struct TVZoomButtons: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: 6) {
            button("Zoom Out", systemImage: "minus.magnifyingglass") { session.zoomOut() }
            button("Zoom In", systemImage: "plus.magnifyingglass") { session.zoomIn() }
        }
    }

    private func button(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
#endif
