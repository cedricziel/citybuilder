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
                ZStack {
                    TVMapInputHost(remote: tvRemote)
                    TVReticleOverlay(remote: tvRemote)
                        .allowsHitTesting(false)
                }
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

/// In the HUD the focus engine owns the remote: Back closes an open
/// drawer or returns to the map, and Play/Pause returns to the map.
struct TVHUDCommands: ViewModifier {
    let root: CityRootView

    func body(content: Content) -> some View {
        content
            // While the map owns the remote, the HUD takes no focus, so
            // the focus engine cannot land on it.
            .disabled(root.tvRemote?.mapper.focus == .map)
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
/// style of the armed tool, the four tiles a click would step to, and the
/// tooltip of a building the reticle rests on. Design D1, D2, D6.
struct TVReticleOverlay: View {
    let remote: TVRemoteController

    private var session: GameSession {
        remote.session
    }

    var body: some View {
        if remote.mapper.focus == .map {
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
            .accessibilityLabel("Reticle at \(session.reticleTile.x), \(session.reticleTile.y)")
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
        let tile = session.reticleHint(direction)
        return Text("\(tile.x),\(tile.y)")
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 6)
            .background(.black.opacity(0.45), in: Capsule())
            .foregroundStyle(.white)
    }

    /// Up steps north-east, right south-east, down south-west and left
    /// north-west; each hint sits beyond the tile it names, along the
    /// same diagonal, so the four labels never overlap.
    private static func offset(_ direction: RemoteDirection, halfWidth: Double, halfHeight: Double) -> CGSize {
        switch direction {
        case .up: CGSize(width: halfWidth * 2, height: -halfHeight * 2)
        case .right: CGSize(width: halfWidth * 2, height: halfHeight * 2)
        case .down: CGSize(width: -halfWidth * 2, height: halfHeight * 2)
        case .left: CGSize(width: -halfWidth * 2, height: -halfHeight * 2)
        }
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
#endif
